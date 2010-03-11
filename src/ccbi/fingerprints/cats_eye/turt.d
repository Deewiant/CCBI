// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:11:55

module ccbi.fingerprints.cats_eye.turt;

import tango.io.device.File;
import tango.math.Math : PI, cos, sin, round = rndint, abs;
import tango.text.convert.Integer : format, itoa;

// WORKAROUND: http://www.dsource.org/projects/dsss/ticket/175
import tango.text.xml.DocPrinter;

import ccbi.fingerprint;

// 0x54555254: TURT
// Simple Turtle Graphics Library
// ------------------------------

mixin (Fingerprint!(
	"TURT",

	"A", "queryHeading",
	"B", "back",
	"C", "penColour",
	"D", "showDisplay",
	"E", "queryPen",
	"F", "forward",
	"H", "setHeading",
	"I", "printDrawing",
	"L", "turnLeft",
	"N", "clearPaper",
	"P", "penPosition",
	"Q", "queryPosition",
	"R", "turnRight",
	"T", "teleport",
	"U", "queryBounds"
));

const TURT_FILE_INIT = "CCBI_TURT.svg";

// {{{ Turtle coordinates

// fixed point with 5 decimals
// tc meaning "turtle coordinate"
typedef int tc;

// Add padding to get nicer viewBoxes for small drawings
enum : tc {
	PADDING = 2,
	MIN = int.min + PADDING,
	MAX = int.max - PADDING
}

uint getInt(tc c) { return abs(cast(int)c) / 10000; }
uint getDec(tc c) { return abs(cast(int)c) % 10000; }

unittest {
	assert (getDec(1) == 1);
	assert (getInt(1) == 0);
	assert (getDec( 16383_9999) ==  9999);
	assert (getInt( 16383_9999) == 16383);
	assert (getDec(-16383_9999) ==  9999);
	assert (getInt(-16383_9999) == 16383);
}

char[] tcToString(tc n) {
	static assert (MIN >= -999_999_999 && MAX <= 999_999_999);
	char[10] buf;
	return itoa(buf, n);
}
// }}}
// {{{ Point, Turtle, Drawing
struct Point {
	tc x, y;

	static assert (is(typeof(x) == typeof(y)));
	static assert (typeof(x).sizeof <= cell.sizeof);
}

struct Turtle {
	Drawing pic;
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
		if (dx > 0 && p.x > MAX - dx)
			p.x = MAX;
		else if (dx < 0 && p.x < MIN - dx)
			p.x = MIN;
		else
			p.x += dx;

		if (dy > 0 && p.y > MAX - dy)
			p.y = MAX;
		else if (dy < 0 && p.y < MIN - dy)
			p.y = MIN;
		else
			p.y += dy;

		// a -> ... -> z is equivalent to a -> z if not drawing
		// so only add path if drawing
		if (penDown) {
			pic.addPath(p, true, colour);
			newDraw();
			movedWithoutDraw = false;
		} else
			movedWithoutDraw = true;
	}

	void newDraw() {
		if (p.x < pic.min.x)
			pic.min.x = p.x;
		else if (p.x > pic.max.x)
			pic.max.x = p.x;

		if (p.y < pic.min.y)
			pic.min.y = p.y;
		else if (p.y > pic.max.y)
			pic.max.y = p.y;
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

template TURT() {

import tango.math.Math : PI, round = rndint;
import tango.text.convert.Integer : format;
import tango.text.xml.Document;
import tango.text.xml.DocPrinter;

char[] filename = TURT_FILE_INIT;
Turtle turt;

// {{{ helpers

real toRad(cell c) { return                 (PI / 180.0) * c;  }
cell toDeg(real r) { return cast(cell)round((180.0 / PI) * r); }

uint toRGB(cell c) { return cast(uint)(c & ((1 << 24) - 1)); }

char[] toCSSColour(uint c) {
	const HEX = "0123456789ABCDEF";
	static char[7] buf = "#rrggbb";

	buf[1] = HEX[c >> 20 & 0xf];
	buf[2] = HEX[c >> 16 & 0xf];
	buf[3] = HEX[c >> 12 & 0xf];
	buf[4] = HEX[c >>  8 & 0xf];
	buf[5] = HEX[c >>  4 & 0xf];
	buf[6] = HEX[c >>  0 & 0xf];

	// #rgb if possible
	if (buf[1] == buf[2] && buf[3] == buf[4] && buf[5] == buf[6]) {
		buf[2] = buf[3];
		buf[3] = buf[5];
		if (buf[1..4] == "f00")
			return "red";
		return buf[0..4];
	}
	switch (buf[1..$]) {
		case "008000": return "green";
		case "008080": return "teal";
		case "4b0082": return "indigo";
		case "800000": return "maroon";
		case "800080": return "purple";
		case "808000": return "olive";
		case "808080": return "grey";
		case "a0522d": return "sienna";
		case "a52a2a": return "brown";
		case "c0c0c0": return "silver";
		case "cd853f": return "peru";
		case "d2b48c": return "tan";
		case "da70d6": return "orchid";
		case "dda0dd": return "plum";
		case "ee82ee": return "violet";
		case "f0e68c": return "khaki";
		case "f0ffff": return "azure";
		case "f5deb3": return "wheat";
		case "f5f5dc": return "beige";
		case "fa8072": return "salmon";
		case "faf0e6": return "linen";
		case "ff6347": return "tomato";
		case "ff7f50": return "coral";
		case "ffa500": return "orange";
		case "ffc0cb": return "pink";
		case "ffd700": return "gold";
		case "ffe4c4": return "bisque";
		case "fffafa": return "snow";
		case "fffff0": return "ivory";
		default: return buf;
	}
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
	auto p = c in turt.pic.dotColourCounts;
	if (p)
		++*p;
	else
		turt.pic.dotColourCounts[c] = 1;
	return c;
}

void addPoint() {
	// replace an old point if possible
	auto oldColour = turt.p in turt.pic.dots;
	if (oldColour) {
		if (*oldColour != turt.colour) {
			--turt.pic.dotColourCounts[*oldColour];
			turt.pic.dots[turt.p] = dotColour(turt.colour);
		}
		return;
	}

	turt.pic.dots[turt.p] = dotColour(turt.colour);
	turt.newDraw();
}

void clearWithColour(uint c) {
	turt.pic.bgColour = c;

	turt.pic.min = turt.pic.max = Point(0,0);
	turt.pic.dots = null;
	turt.pic.dotColourCounts = null;
	delete turt.pic.pathBeg;
}
// }}}
// {{{ instructions

// Turn Left, Turn Right, Set Heading
void turnLeft()   { turt.heading -= toRad(cip.stack.pop); turt.normalize(); }
void turnRight()  { turt.heading += toRad(cip.stack.pop); turt.normalize(); }
void setHeading() { turt.heading  = toRad(cip.stack.pop); turt.normalize(); }

// Forward, Back
void forward() { turt.move( cast(tc)cip.stack.pop); }
void back()    { turt.move(-cast(tc)cip.stack.pop); }

// Pen Position
void penPosition() {
	switch (cip.stack.pop) {
		case 0:
			tryAddPoint();
			turt.penDown = false; break;
		case 1: turt.penDown = true; break;
		default: reverse(); break;
	}
}

// Pen Colour
void penColour() {
	turt.colour = toRGB(cip.stack.pop);
}

// Clear Paper with Colour
void clearPaper() {
	clearWithColour(toRGB(cip.stack.pop));
}

// Show Display
void showDisplay() {
	switch (cip.stack.pop) {
		case 0: break;                // TODO: turn off window
		case 1: tryAddPoint(); break; // TODO: turn on window
		default: reverse(); break;
	}
}

// Teleport
void teleport() {
	tryAddPoint();

	turt.p.y = cast(tc)cip.stack.pop;
	turt.p.x = cast(tc)cip.stack.pop;

	turt.movedWithoutDraw = true;
}

// Query Pen
void queryPen() {
	cip.stack.push(cast(cell)turt.penDown);
}

// Query Heading
void queryHeading() {
	cip.stack.push(toDeg(turt.heading));
}

// Query Position
void queryPosition() {
	cip.stack.push(
		cast(cell)turt.p.x,
		cast(cell)turt.p.y);
}

// Query Bounds
void queryBounds() {
	cip.stack.push(
		cast(cell)MIN,
		cast(cell)MIN,
		cast(cell)MAX,
		cast(cell)MAX);
}

// Print Current Drawing
// we use the SVG format
void printDrawing() {
	tryAddPoint();

	static if (GOT_TRDS)
		if (state.tick < ioAfter)
			return;

	File file;
	try file = new typeof(file)(filename, file.WriteCreate);
	catch {
		return reverse();
	}
	scope (exit)
		file.close();

	auto
		width  = turt.pic.max.x + PADDING - (turt.pic.min.x - PADDING),
		height = turt.pic.max.y + PADDING - (turt.pic.min.y - PADDING);

	auto
		minX    = tcToString(turt.pic.min.x - PADDING).dup,
		minY    = tcToString(turt.pic.min.y - PADDING).dup,
		widthS  = tcToString(width).dup,
		heightS = tcToString(height).dup;

	auto viewBox =
		minX   ~ " " ~
		minY   ~ " " ~
		widthS ~ " " ~
		heightS;

	auto svg = new Document!(char);

	svg.header;

	// no doctype as it's not recommended for 1.1
	// see for instance http://jwatt.org/svg/authoring/#doctype-declaration

	auto root = svg.tree
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
		"path{fill:none;stroke-width:1px;"
		"stroke-linecap:round;stroke-linejoin:round}";

	root
		.element(null, "title")
		.data(
			"TURT picture generated by "
			"the Conforming Concurrent Befunge-98 Interpreter");

	if (turt.pic.bgColour != turt.pic.TRANSPARENT)
		root
			.element  (null, "rect")
			.attribute(null, "x",      minX)
			.attribute(null, "y",      minY)
			.attribute(null, "width",  widthS)
			.attribute(null, "height", heightS)
			.attribute(null, "fill",   toCSSColour(turt.pic.bgColour).dup);

	if (auto p = turt.pic.pathBeg) {
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

			auto drawing = p != turt.pic.path || p.penDown;

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
					pathdata ~= tcToString(prev.p.x);
					pathdata ~= ",";
					pathdata ~= tcToString(prev.p.y);
					pathdata ~= " ";
					pathdata ~= NewlineString;
					i = 0;
				}

				pathdata ~= "L";

			// if the last one doesn't draw anything, skip it, it's useless
			// (i.e. if !p.penDown && p == pic.path)
			} else if (p != turt.pic.path)
				pathdata ~= "M";

			if (drawing) {
				pathdata ~= tcToString(p.p.x);
				pathdata ~= ",";
				pathdata ~= tcToString(p.p.y);
				pathdata ~= " ";
			}
		}

		path.attribute(null, "d", pathdata[0..$-1]);
	}

	char[][uint] colours;
	ushort cCnt = 1;
	char[12] classBuf = ".c4294967295";

	foreach (dot, colour; turt.pic.dots) {

		auto dotElem = root
			.element  (null, "circle")
			.attribute(null, "cx",   tcToString(dot.x).dup)
			.attribute(null, "cy",   tcToString(dot.y).dup)
			.attribute(null, "r",    ".5");

		auto colourS = toCSSColour(colour);

		auto n = turt.pic.dotColourCounts[colour];

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

	file.write((new DocPrinter!(char))(svg));
	file.write(NewlineString);
}

// }}}

}
