// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:11:55

module ccbi.fingerprints.cats_eye.turt; private:

import tango.io.FileConduit;
import tango.math.Math : PI, cos, sin, round = rndint, abs;
import tango.io.Stdout : Stdout;

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
}

const TURT_FILE_INIT = "CCBI_TURT.svg";
char[] filename = TURT_FILE_INIT;

// fixed point with 5 decimals
// tc meaning "turtle coordinate"
typedef int tc;

// SVGT limits all numbers to -32767.9999 - 32767.9999, not -32768 - 32767
// that limits our width to 32767.9999, hence the min and max values
// we add a PADDING value to get nice viewBoxes for small drawings
enum : tc {
	PADDING = 10,
	MIN = -16383_9999 + PADDING,
	MAX =  16383_9999 - PADDING
}

 int getInt(tc c) { return (c < 0 ? -c : c) / 1000; }
uint getDec(tc c) { return abs(cast(int)c) % 1000; }

static assert (getDec(cast(tc)1) == 1);
static assert (getInt(cast(tc)1) == 0);

struct Point {
	tc x, y;

	static assert (is(typeof(x) == typeof(y)));
	static assert (typeof(x).sizeof <= cell.sizeof);
}

struct Turtle {
	Point p;

	real heading, sin, cos;
	uint colour;
	bool penDown, movedWithoutDraw = true;

	void normalize() {
		while (heading > 2*PI)
			heading -= 2*PI;
		while (heading < 0)
			heading += 2*PI;
		sin = .sin(heading);
		cos = .cos(heading);
	}

	void move(tc distance) {
		// have to check for under-/overflow...

		tc dx = cast(tc)round(cos * distance),
		   dy = cast(tc)round(sin * distance);

		auto nx = p.x + dx;
		if (nx > MAX)
			nx = MAX;
		else if (nx < MIN)
			nx = MIN;
		p.x = nx;

		auto ny = p.x + dy;
		if (ny > MAX)
			ny = MAX;
		else if (ny < MIN)
			ny = MIN;
		p.y = ny;

		// a -> ... -> z is equivalent to a -> z if not drawing
		if (penDown || (pic.path && pic.path.penDown)) {
			pic.addPath(p, penDown, colour);
			newDraw();
			movedWithoutDraw = false;
		} else
			movedWithoutDraw = true;
	}

	Point min;

	void newDraw() {
		if (p.x < min.x)
			min.x = p.x;

		if (p.y < min.y)
			min.y = p.y;
	}
}

struct Drawing {
	struct Dot {
		Point p;
		uint colour;
	}

	struct Path {
		Dot d;

		bool penDown;
		Path* next;

		static Path opCall(Point a, bool b, uint c) {
			Path p;
			with (p) {
				d = Dot(a, c);
				penDown = b;
			}
			return p;
		}
	}

	Dot[] dots;
	Path* pathBeg, path;
	uint bgColour;

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
alias Drawing.Path Path;

Turtle turt;
Drawing pic;

// helpers...
real toRad(cell c) {
	return (PI / 180.0) * c;
}
cell toDeg(real r) {
	return cast(cell)round((180.0 / PI) * r);
}

uint toRGB(cell c) {
	 return cast(uint)(c & ((1 << 24) - 1));
}

// if we've moved to a location with the pen up, and the pen is now down, it
// may be that we'll move to another location with the pen down so there's no
// need to add a point unless the pen is lifted up or we need to look at the drawing
void tryAddPoint() {
	if (turt.movedWithoutDraw && turt.penDown)
		addPoint();
}

void addPoint() {
	foreach (inout dot; pic.dots) {
		if (dot.p == turt.p) {
			if (dot.colour != turt.colour)
				dot.colour = turt.colour;
			return;
		}
	}

	pic.dots ~= Drawing.Dot(turt.p, turt.colour);
	turt.newDraw();
}

// instructions henceforth
//////////////////////////

// Turn Left, Turn Right, Set Heading
void turnLeft()   { turt.heading += toRad(ip.stack.pop); turt.normalize(); }
void turnRight()  { turt.heading -= toRad(ip.stack.pop); turt.normalize(); }
void setHeading() { turt.heading  = toRad(ip.stack.pop); turt.normalize(); }

// Forward, Back
void forward() { turt.move( cast(tc)ip.stack.pop); }
void back()    { turt.move(-cast(tc)ip.stack.pop); }

// Pen Position
void penPosition() {
	switch (ip.stack.pop) {
		case 0:	tryAddPoint();
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
	pic.bgColour = toRGB(ip.stack.pop);
	delete pic.pathBeg;
	delete pic.dots;
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
	ip.stack.push(cast(cell)turt.p.x);
	ip.stack.push(cast(cell)turt.p.y);
}

// Query Bounds
void queryBounds() {
	ip.stack.push(
		cast(cell)MIN,
		cast(cell)MIN,
		cast(cell)MAX,
		cast(cell)MAX
	);
}

// Print Current Drawing
// we use the SVG format
void printDrawing() {
	tryAddPoint();

	static char[] toCSSColour(uint c) {
		return Stdout.layout.convert("#{:x2}{:x2}{:x2}", c & 0xff, c >> 8 & 0xff, c >> 16 & 0xff);
	}

	FileConduit file;
	try file = new typeof(file)(filename, WriteCreate);
	catch {
		return reverse();
	}
	scope (exit)
		file.close();

	// if we need more size (unlikely), baseProfile="full" below
	static assert (MAX - MIN <= 32767_9999);

	file.output.write(Stdout.layout.convert(
		`<?xml version ="1.0" standalone="no"?>` ~ NewlineString ~
		`<svg version="1.1" baseProfile="tiny" xmlns="http://www.w3.org/2000/svg" viewBox="{}{}.{:d4} {}{}.{:d4} {}{}.{:d4} {}{}.{:d4}">`,

		(turt.min.x - PADDING) < 0 ? "-" : "", getInt(turt.min.x - PADDING), getDec(turt.min.x - PADDING),
		(turt.min.y - PADDING) < 0 ? "-" : "", getInt(turt.min.y - PADDING), getDec(turt.min.y - PADDING),
		(PADDING - turt.min.x) < 0 ? "-" : "", getInt((PADDING - turt.min.x)*cast(tc)2), getDec((PADDING - turt.min.x)*cast(tc)2),
		(PADDING - turt.min.y) < 0 ? "-" : "", getInt((PADDING - turt.min.y)*cast(tc)2), getDec((PADDING - turt.min.y)*cast(tc)2)
	));

	const char[]
		PATH_START_STRING = NewlineString ~ `<path stroke="{}" stroke-linecap="round" d="`,
		PATH_END_STRING   = NewlineString ~ `"/>`;

	auto p = pic.pathBeg;

	if (p) {
		file.output.write(Stdout.layout.convert(PATH_START_STRING, toCSSColour(p.d.colour)));

		// need to move to the start if we draw immediately
		if (p.penDown)
			file.output.write("M0,0 ");
		file.output.write(NewlineString ~ \t);

		// SVG suggests a maximum line length of 255
		ubyte i = 0;
		const typeof(i) NODES_PER_LINE = 10;

		for (auto prev = p; p; prev = p, p = p.next) {
			if (p.penDown) {
				// start a new path if the colour changes
				if (p.d.colour != prev.d.colour)
					file.output.write(
						Stdout.layout.convert(PATH_END_STRING ~ PATH_START_STRING, toCSSColour(p.d.colour)) ~
						\"~NewlineString~\t
					);

				file.output.write(Stdout.layout.convert(
					"L{}{}.{:d4},{}{}.{:d4} ",
					(p.d.p.x < 0) ? "-" : "", getInt(p.d.p.x), getDec(p.d.p.x),
					(p.d.p.y < 0) ? "-" : "", getInt(p.d.p.y), getDec(p.d.p.y)
				));

			// if the last one doesn't draw anything, skip it, it's useless
			} else if (p != pic.path) {
				file.output.write(Stdout.layout.convert(
					"M{}{}.{:d4},{}{}.{:d4} ",
					(p.d.p.x < 0) ? "-" : "", getInt(p.d.p.x), getDec(p.d.p.x),
					(p.d.p.y < 0) ? "-" : "", getInt(p.d.p.y), getDec(p.d.p.y)
				));
			}

			if (++i >= NODES_PER_LINE) {
				file.output.write(NewlineString~\t~NewlineString);
				i = 0;
			}
		}

		file.output.write(PATH_END_STRING);
	}

	foreach (dot; pic.dots) {
		file.output.write(Stdout.layout.convert(
			NewlineString ~ `<circle cx="{}{}.{:d4}" cy="{}{}.{:d4}" r="0.00005" fill="{}" />`,
			(dot.p.x < 0) ? "-" : "", getInt(dot.p.x), getDec(dot.p.x),
			(dot.p.y < 0) ? "-" : "", getInt(dot.p.y), getDec(dot.p.y),
			toCSSColour(dot.colour)
		));
	}

	file.output.write(NewlineString ~ "</svg>");
}
