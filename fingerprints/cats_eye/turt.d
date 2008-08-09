// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:11:55

module ccbi.fingerprints.cats_eye.turt; private:

import tango.io.device.FileConduit;
import tango.math.Math            : PI, cos, sin, round = rndint, abs;
import tango.text.convert.Integer : format;
import tango.text.xml.Document;
import tango.text.xml.DocPrinter;

import ccbi.fingerprint;
import ccbi.instructions : reverse;
import ccbi.ip;
import ccbi.stdlib : NewlineString, WriteCreate;

// 0x54555254: TURT
// Simple Turtle Graphics Library
// ------------------------------

static this() {
	mixin (Code!("TURT"));

	fingerprints[TURT]['A'] =& queryHeading;
	fingerprints[TURT]['B'] =& back;
	fingerprints[TURT]['C'] =& penColour;
	fingerprints[TURT]['D'] =& showDisplay;
	fingerprints[TURT]['E'] =& queryPen;
	fingerprints[TURT]['F'] =& forward;
	fingerprints[TURT]['H'] =& setHeading;
	fingerprints[TURT]['I'] =& printDrawing;
	fingerprints[TURT]['L'] =& turnLeft;
	fingerprints[TURT]['N'] =& clearPaper;
	fingerprints[TURT]['P'] =& penPosition;
	fingerprints[TURT]['Q'] =& queryPosition;
	fingerprints[TURT]['R'] =& turnRight;
	fingerprints[TURT]['T'] =& teleport;
	fingerprints[TURT]['U'] =& queryBounds;

	fingerprintDestructors[TURT] =& dtor;
}

const TURT_FILE_INIT = "CCBI_TURT.svg";
char[] filename = TURT_FILE_INIT;

Turtle turt;
Drawing pic;

// {{{ turtle coordinates

// fixed point with 5 decimals
// tc meaning "turtle coordinate"
typedef int tc;

// we add a PADDING value to get nice viewBoxes for small drawings
// the min and max were +-32767_9999 originally due to using SVG Tiny
// the advantages of that were considered few, and thus they were expanded
// but only this much, since even this is pretty huge
enum : tc {
	PADDING = 10,
	MIN = -99999_9999 + PADDING,
	MAX =  99999_9999 - PADDING
}

uint getInt(tc c) { return abs(cast(int)c) / 10000; }
uint getDec(tc c) { return abs(cast(int)c) % 10000; }

static assert (getDec(cast(tc)1) == 1);
static assert (getInt(cast(tc)1) == 0);
static assert (getDec(cast(tc)16383_9999) ==  9999);
static assert (getInt(cast(tc)16383_9999) == 16383);
static assert (getDec(cast(tc)-16383_9999) ==  9999);
static assert (getInt(cast(tc)-16383_9999) == 16383);

char[] toString(tc n) {
	static assert (MIN >= -99999_9999 && MAX <= 99999_9999);

	static char[11] buf;
	size_t i = 0;

	if (n == 0)
		return "0";

	else if (n < 0)
		buf[i++] = '-';

	uint
		intPart = getInt(n),
		decPart = getDec(n);

	if (intPart > 0) {
		auto s = format(buf[i..i+5], intPart, "d");

		// move s to the left
		// so we don't get a buf like '-  123'
		foreach (c; s)
			buf[i++] = c;
	}

	if (decPart > 0) {
		buf[i++] = '.';

		size_t beg = i;
		format(buf[i..i+4], decPart, "d4");
		i += 4;

		// remove trailing zeroes
//		size_t tz = 0;
		while (buf[i-1] == '0') {
//			++tz;
			--i;
		}

		/+ BREAKS EVERY SVG VIEWER I TRIED (RAM/CPU usage hit the roof)
		// switch to scientific notation if it's more compact
		// it only is when intPart is 0 (so we can lose the leading zeroes)
		if (intPart == 0) {
			size_t lz = 0;
			while (buf[beg + lz] == '0')
				++lz;

			size_t
				currentLength    = 4 - tz + 1, // 1 for the decimal point
				numberLength     = 4 - tz - lz,
				scientificLength = numberLength + "e-x".length;

			if (currentLength > scientificLength) {
				i = 0;
				for (; i < numberLength; ++i)
					buf[i] = buf[beg + lz + i];
				buf[i++] = 'e';
				buf[i++] = '-';
				buf[i++] = '4' - tz;
			}
		} +/
	}

	return buf[0..i];
}
// }}}
// {{{ Point, Turtle, Drawing
struct Point {
	tc x, y;

	static assert (is(typeof(x) == typeof(y)));
	static assert (typeof(x).sizeof <= cell.sizeof);
}

struct Turtle {
	Point p = {0,0};

	real heading = 0, sin = 0, cos = 1;
	uint colour = 0;
	bool penDown = false, movedWithoutDraw = true;

	void normalize() {
		heading %= 2*PI;
		if (heading > 2*PI)
			heading -= 2*PI;
		else if (heading < 0)
			heading += 2*PI;
		sin = .sin(heading);
		cos = .cos(heading);
	}

	void move(tc distance) {

		// if we are to start drawing now, but last move we didn't draw, add a
		// non-drawing path node to here before moving
		if (penDown && movedWithoutDraw)
			pic.addPath(p, false, 0);

		tc
			dx = cast(tc)round(cos * distance),
			dy = cast(tc)round(sin * distance);

		// have to check for under-/overflow...
		auto nx = p.x + dx;
		if (nx > MAX)
			nx = MAX;
		else if (nx < MIN)
			nx = MIN;
		p.x = nx;

		auto ny = p.y + dy;
		if (ny > MAX)
			ny = MAX;
		else if (ny < MIN)
			ny = MIN;
		p.y = ny;

		// a -> ... -> z is equivalent to a -> z if not drawing
		// so only add path if drawing
		if (penDown) {
			pic.addPath(p, true, colour);
			newDraw();
			movedWithoutDraw = false;
		} else
			movedWithoutDraw = true;
	}
}

struct Drawing {

	struct Path {
		Point p;
		bool penDown;
		uint colour;

		Path* next;
	}

	uint[Point] dots;
	uint[uint] dotColourCounts;

	Point min = {0,0}, max = {0,0};

	Path* pathBeg, path;

	const uint TRANSPARENT = 0xff000000;
	auto bgColour = TRANSPARENT;

	void addPath(Point pt, bool penDown, uint colour) {
		Path* p = new Path;
		*p = Path(pt, penDown, colour);

		if (pathBeg is null)
			pathBeg = p;
		else
			path.next = p;
		path = p;
	}
}
// }}}
// {{{ helpers

void newDraw() {
	if (turt.p.x < pic.min.x)
		pic.min.x = turt.p.x;
	else if (turt.p.x > pic.max.x)
		pic.max.x = turt.p.x;

	if (turt.p.y < pic.min.y)
		pic.min.y = turt.p.y;
	else if (turt.p.y > pic.max.y)
		pic.max.y = turt.p.y;
}

real toRad(cell c) { return                 (PI / 180.0) * c;  }
cell toDeg(real r) { return cast(cell)round((180.0 / PI) * r); }

uint toRGB(cell c) { return cast(uint)(c & ((1 << 24) - 1)); }

char[] toCSSColour(uint c) {
	static char[7] buf = "#rrggbb";

	format(buf[1..3], c >> 16 & 0xff, "x2");
	format(buf[3..5], c >>  8 & 0xff, "x2");
	format(buf[5..7], c       & 0xff, "x2");

	// #rgb if possible
	if (buf[1] == buf[2] && buf[3] == buf[4] && buf[5] == buf[6]) {
		buf[2] = buf[3];
		buf[3] = buf[5];
		return buf[0..4];
	} else
		return buf;
}

// If we've moved to a location with the pen up, and the pen is now down, it
// may be that we'll move to another location with the pen down. Thus there's
// no need to add a point unless the pen is lifted up or we need to look at the
// drawing.
void tryAddPoint() {
	if (turt.movedWithoutDraw && turt.penDown)
		addPoint();
}

uint dotColour(uint c) {
	auto p = c in pic.dotColourCounts;
	if (p)
		++*p;
	else
		pic.dotColourCounts[c] = 1;
	return c;
}

void addPoint() {
	// replace an old point if possible
	auto oldColour = turt.p in pic.dots;
	if (oldColour) {
		if (*oldColour != turt.colour) {
			--pic.dotColourCounts[*oldColour];
			pic.dots[turt.p] = dotColour(turt.colour);
		}
		return;
	}

	pic.dots[turt.p] = dotColour(turt.colour);
	newDraw();
}

void clearWithColour(uint c) {
	pic.bgColour = c;

	pic.min = pic.max = Point(0,0);
	pic.dots = null;
	pic.dotColourCounts = null;
	delete pic.pathBeg;
}
// }}}
// {{{ instructions and dtor

void dtor() {
	clearWithColour(pic.TRANSPARENT);
}

// Turn Left, Turn Right, Set Heading
void turnLeft()   { turt.heading -= toRad(ip.stack.pop); turt.normalize(); }
void turnRight()  { turt.heading += toRad(ip.stack.pop); turt.normalize(); }
void setHeading() { turt.heading  = toRad(ip.stack.pop); turt.normalize(); }

// Forward, Back
void forward() { turt.move( cast(tc)ip.stack.pop); }
void back()    { turt.move(-cast(tc)ip.stack.pop); }

// Pen Position
void penPosition() {
	switch (ip.stack.pop) {
		case 0:
			tryAddPoint();
			turt.penDown = false; break;
		case 1: turt.penDown = true;  break;
		default: reverse(); break;
	}
}

// Pen Colour
void penColour() {
	turt.colour = toRGB(ip.stack.pop);
}

// Clear Paper with Colour
void clearPaper() {
	clearWithColour(toRGB(ip.stack.pop));
}

// Show Display
void showDisplay() {
	switch (ip.stack.pop) {
		case 0: break;                // TODO: turn off window
		case 1: tryAddPoint(); break; // TODO: turn on window
		default: reverse(); break;
	}
}

// Teleport
void teleport() {
	tryAddPoint();

	turt.p.y = cast(tc)ip.stack.pop;
	turt.p.x = cast(tc)ip.stack.pop;

	turt.movedWithoutDraw = true;
}

// Query Pen
void queryPen() {
	ip.stack.push(cast(cell)turt.penDown);
}

// Query Heading
void queryHeading() {
	ip.stack.push(toDeg(turt.heading));
}

// Query Position
void queryPosition() {
	ip.stack.push(
		cast(cell)turt.p.x,
		cast(cell)turt.p.y);
}

// Query Bounds
void queryBounds() {
	ip.stack.push(
		cast(cell)MIN,
		cast(cell)MIN,
		cast(cell)MAX,
		cast(cell)MAX);
}

// Print Current Drawing
// we use the SVG format
void printDrawing() {
	tryAddPoint();

	FileConduit file;
	try file = new typeof(file)(filename, WriteCreate);
	catch {
		return reverse();
	}
	scope (exit)
		file.close();

	auto
		width  = pic.max.x + PADDING - (pic.min.x - PADDING),
		height = pic.max.y + PADDING - (pic.min.y - PADDING);

	auto
		minX    = toString(pic.min.x - PADDING).dup,
		minY    = toString(pic.min.y - PADDING).dup,
		widthS  = toString(width).dup,
		heightS = toString(height).dup;

	auto viewBox =
		minX   ~ " " ~
		minY   ~ " " ~
		widthS ~ " " ~
		heightS;

	auto svg = new Document!(char);

	svg.header;

	// no doctype as it's not recommended for 1.1
	// see for instance http://jwatt.org/svg/authoring/#doctype-declaration

	auto root = svg.root
		.element  (null, "svg")
		.attribute(null, "version",     "1.1")
		.attribute(null, "baseProfile", "full")
		.attribute(null, "xmlns",       "http://www.w3.org/2000/svg")
		.attribute(null, "viewBox",     viewBox);

	// we add the data later
	auto style = root
		.element  (null, "defs")
		.element  (null, "style")
		.attribute(null, "type", "text/css");

	char[] styleData =
		"path{fill:none;stroke-width:.0001px;"
		"stroke-linecap:round;stroke-linejoin:round}";

	root
		.element(null, "title")
		.data(
			"TURT picture generated by "
			"the Conforming Concurrent Befunge-98 Interpreter");

	if (pic.bgColour != pic.TRANSPARENT)
		root
			.element  (null, "rect")
			.attribute(null, "x",      minX)
			.attribute(null, "y",      minY)
			.attribute(null, "width",  widthS)
			.attribute(null, "height", heightS)
			.attribute(null, "fill",   toCSSColour(pic.bgColour).dup);

	if (auto p = pic.pathBeg) {
		typeof(root) newPath(uint colour) {
			return root
				.element  (null, "path")
				.attribute(null, "stroke", toCSSColour(colour).dup);
		}

		auto path = newPath(p.colour);

		char[] pathdata;

		// need to move to the start if we draw immediately
		if (p.penDown)
			pathdata ~= "M0,0";

		pathdata ~= NewlineString;

		// SVG suggests a maximum line length of 255
		ubyte i = 0;
		const typeof(i) NODES_PER_LINE = 10;

		for (auto prev = p; p; prev = p, p = p.next) {

			auto drawing = p != pic.path || p.penDown;

			if (drawing && i++ >= NODES_PER_LINE) {
				// remove the trailing space from the last line
				pathdata.length = pathdata.length - 1;

				pathdata ~= NewlineString;
				i = 0;
			}

			if (p.penDown) {
				// start a new path if the colour changes
				if (p.colour != prev.colour) {
					path.attribute(null, "d", pathdata[0..$-1]);

					path = newPath(p.colour);
					pathdata = "M";
					pathdata ~= toString(prev.p.x);
					pathdata ~= ",";
					pathdata ~= toString(prev.p.y);
					pathdata ~= " ";
					pathdata ~= NewlineString;
					i = 0;
				}

				pathdata ~= "L";

			// if the last one doesn't draw anything, skip it, it's useless
			// (i.e. if !p.penDown && p == pic.path)
			} else if (p != pic.path)
				pathdata ~= "M";

			if (drawing) {
				pathdata ~= toString(p.p.x);
				pathdata ~= ",";
				pathdata ~= toString(p.p.y);
				pathdata ~= " ";
			}
		}

		path.attribute(null, "d", pathdata[0..$-1]);
	}

	char[][uint] colours;
	ushort cCnt = 1;
	char[12] classBuf = ".c4294967295";

	foreach (dot, colour; pic.dots) {

		auto dotElem = root
  			.element  (null, "circle")
  			.attribute(null, "cx",   toString(dot.x).dup)
  			.attribute(null, "cy",   toString(dot.y).dup)
  			.attribute(null, "r",    ".00005");

		auto colourS = toCSSColour(colour);

		auto n = pic.dotColourCounts[colour];

		// Silly compression follows...
		//
		// when is ".c".length + "{fill:#rrggbb}".length + l + n * ("class='c'".length + l)
		// less than n * "fill='#rrggbb'".length
		// where n is n and l is the length of cCnt's string representation
		// that is, 16+l+n(9+l) < 14n or 16+l+ln < 5n
		// answers are below
		// note how, when cCnt exceeds 9999 (l exceeds 4), we have:
		// fill='#rrggbb'
		// class='c10000'
		// and thus there is no advantage thereafter.
		// similarly, if the colour is #rgb, we have, after 9:
		// fill='#rgb'
		// class='c10'
		if (
			(colourS.length == 7 && (
				(n >=  5 && cCnt <=    9) ||
				(n >=  7 && cCnt <=   99) ||
				(n >= 10 && cCnt <=  999) ||
				(n >= 21 && cCnt <= 9999))
			) ||
			(colourS.length == 4 && (
				(n >= 15 && cCnt <=    9))
			)
		) {
			// we can save space by using a class

			auto s = colour in colours;
			if (!s) {
				auto newClass = format(classBuf[".c".length..$], cCnt, "d10");

				// left align the number...
				size_t i = 1;
				while (newClass[i] == '0' && i < newClass.length)
					++i;
				size_t beg = i;
				for (; i < newClass.length; ++i)
					newClass[i - beg] = newClass[i];

				newClass = classBuf[0 .. i - beg + ".c".length];

				colours[colour] = newClass.dup;
				s = colour in colours;

				styleData ~= NewlineString;
				styleData ~= newClass;
				styleData ~= "{fill:";
				styleData ~= colourS;
				styleData ~= "}";
				++cCnt;
			}

			dotElem.attribute(null, "class", *s);
		} else
			dotElem.attribute(null, "fill", colourS);
	}

	style.data(styleData);

	file.output.write((new DocPrinter!(char))(svg));
	file.output.write(NewlineString);
}

// http://d.puremagic.com/issues/show_bug.cgi?id=1629
private alias DocPrinter!(char) bugzilla_1629_workaround;
// }}}
