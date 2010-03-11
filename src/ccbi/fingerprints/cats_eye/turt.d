// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:11:55

module ccbi.fingerprints.cats_eye.turt;

import tango.math.Math : PI, cos, sin, round = rndint;
import tango.text.convert.Integer : itoa;

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

char[] tcToString(tc n) {
	static assert (MIN >= int.min && MAX <= int.max);

	static char[11] buf = "-2147483648";
	if (n >= 0)
		return itoa(buf, n);
	else {
		auto s = itoa(buf, -n);
		auto ss = (s.ptr - 1)[0 .. s.length+1];
		ss[0] = '-';
		return ss;
	}
}
// }}}
// {{{ Non-template helpers
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
			pic.addPath(p, false, colour);

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
	struct Part {
		bool isDot;
		uint colour;
		union {
			Point dot;
			Point[] path;
		}
	}

	// Order matters! A red dot on top of a blue line is different from a blue
	// line on top of a red dot.
	Part[] parts;

	uint[uint] dotColourCounts;

	Point min = {0,0}, max = {0,0};

	const uint TRANSPARENT = 0xff000000;
	auto bgColour = TRANSPARENT;

	// No two consecutive calls will have penDown = false
	void addPath(Point pt, bool penDown, uint colour) {

		if (penDown) {
			// We should get a !penDown call first
			assert (parts.length > 0);
			assert (!parts[$-1].isDot);

			if (parts[$-1].colour == colour)
				return parts[$-1].path ~= pt;
		}

		// Make a new path.
		Part part;
		part.isDot = false;
		part.colour = colour;

		// Be sure when it comes to unions...
		part.path = null;

		// Start from where we last ended
		if (penDown)
			part.path ~= parts[$-1].path[$-1];

		part.path ~= pt;

		parts ~= part;
	}
}
// }}}

template TURT() {

import tango.math.Math : PI, round = rndint;
import tango.text.convert.Integer : format;
import tango.text.convert.Format;
import tango.text.xml.Document;
import tango.text.xml.DocPrinter;
import tango.time.Clock;

char[] filename = TURT_FILE_INIT;
Turtle turt;

// {{{ Helpers

// If we've moved to a location with the pen up, and the pen is now down, it
// may be that we'll move to another location with the pen down. Thus there's
// no need to add a point unless the pen is lifted up or we need to look at the
// drawing: in these cases, call tryAddPoint.
void tryAddPoint() {
	if (turt.movedWithoutDraw && turt.penDown)
		addPoint();
}

void addPoint() {
	auto count = turt.colour in turt.pic.dotColourCounts;
	if (count)
		++*count;
	else
		turt.pic.dotColourCounts[turt.colour] = 1;

	Drawing.Part part;
	part.isDot = true;
	part.colour = turt.colour;
	part.dot = turt.p;

	turt.pic.parts ~= part;
	turt.newDraw();
}

void clearWithColour(uint c) {
	turt.pic.bgColour = c;

	turt.pic.min = turt.pic.max = Point(0,0);
	turt.pic.parts.length = 0;
	turt.pic.dotColourCounts = null;
}
// }}}
// {{{ Instructions

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
			turt.penDown = false;
			break;
		case 1:
			turt.penDown = true;
			break;

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
		"path{fill:none;stroke-linecap:round;stroke-linejoin:round}";

	auto date = Clock.toDate;
	auto desc = Format(
		"TURT drawing from {}. Generated by " ~VERSION_STRING~ ", on "
		"{}-{:d2}-{:d2}T{:d2}:{:d2}:{:d2}Z.",
		fungeArgs[0],
		date.date.year, date.date.month, date.date.day,
		date.time.hours, date.time.minutes, date.time.seconds);

	root
		.element(null, "title")
		.data(desc[0 .. ("TURT drawing from "~fungeArgs[0]).length]);
	root
		.element(null, "desc")
		.data(desc);

	if (turt.pic.bgColour != turt.pic.TRANSPARENT)
		root
			.element  (null, "rect")
			.attribute(null, "x",      minX)
			.attribute(null, "y",      minY)
			.attribute(null, "width",  widthS)
			.attribute(null, "height", heightS)
			.attribute(null, "fill",   toCSSColour(turt.pic.bgColour).dup);

	char[][uint] colours;
	ushort cCnt = 1;
	char[12] classBuf = ".c4294967295";

	void printDot(uint colour, Point dot) { // {{{
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
			dotElem.attribute(null, "fill", colourS.dup);
	} // }}}
	void printPath(uint colour, Point[] ps) { // {{{

		assert (ps.length > 0);

		// Doesn't draw anything: ignore it
		if (ps.length == 1)
			return;

		auto path = root.element  (null, "path")
		                .attribute(null, "stroke", toCSSColour(colour).dup);

		char[] pathdata = "M";

		pathdata ~= tcToString(ps[0].x);
		pathdata ~= ",";
		pathdata ~= tcToString(ps[0].y);
		pathdata ~= " L";

		// SVG suggests a maximum line length of 255
		ubyte i = 1;
		const typeof(i) NODES_PER_LINE = 10;

		foreach (p; ps[1..$]) {
			if (i++ >= NODES_PER_LINE) {
				// remove the trailing space from the previous line
				pathdata.length = pathdata.length - 1;

				pathdata ~= NewlineString;
				i = 0;
			}

			pathdata ~= tcToString(p.x);
			pathdata ~= ",";
			pathdata ~= tcToString(p.y);
			pathdata ~= " ";
		}
		path.attribute(null, "d", pathdata[0..$-1]);
	} // }}}

	foreach (part; turt.pic.parts) {
		if (part.isDot)
			printDot(part.colour, part.dot);
		else
			printPath(part.colour, part.path);
	}

	style.data(styleData);

	file.write((new DocPrinter!(char))(svg));
	file.write(NewlineString);
}

// }}}

}
