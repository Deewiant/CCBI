// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2007-01-18 19:20:04

// The standard Befunge-98 instructions.
module ccbi.instructions.std;

import tango.core.Tuple;

import ccbi.cell;
import ccbi.templateutils;
import ccbi.instructions.utils;

mixin (TemplateLookup!(
	"StdInsFunc", "cell", "c",
	`static assert (false, "No such standard instruction " ~cast(char)c);`,

	WrapForCasing!(
		 ' ', "noOperation", // Befunge-93 only
		 '>', "goEast",
		 '<', "goWest",
		 '^', "goNorth",
		 'v', "goSouth",
		 'h', "goHigh",
		 'l', "goLow",
		 '?', "goAway",
		 ']', "turnRight",
		 '[', "turnLeft",
		 'r', "reverse",
		 'x', "absoluteVector",
		 '#', "trampoline",
		 '@', "stop",
		 'z', "noOperation",
		 'j', "jumpForward",
		 'q', "quit",
		 'k', "iterate",
		 '!', "logicalNot",
		 '`', "greaterThan",
		 '_', "eastWestIf",
		 '|', "northSouthIf",
		 'm', "highLowIf",
		 'w', "compare",
		 '0', PushNumber!(0),
		 '1', PushNumber!(1),
		 '2', PushNumber!(2),
		 '3', PushNumber!(3),
		 '4', PushNumber!(4),
		 '5', PushNumber!(5),
		 '6', PushNumber!(6),
		 '7', PushNumber!(7),
		 '8', PushNumber!(8),
		 '9', PushNumber!(9),
		 'a', PushNumber!(10),
		 'b', PushNumber!(11),
		 'c', PushNumber!(12),
		 'd', PushNumber!(13),
		 'e', PushNumber!(14),
		 'f', PushNumber!(15),
		 '+', "add",
		 '*', "multiply",
		 '-', "subtract",
		 '/', "divide",
		 '%', "remainder",
		 '"', "toggleStringMode",
		'\'', "fetchCharacter",
		 's', "storeCharacter",
		 '$', "pop",
		 ':', "duplicate",
		'\\', "swap",
		 'n', "clearStack",
		 '{', "beginBlock",
		 '}', "endBlock",
		 'u', "stackUnderStack",
		 'g', "get",
		 'p', "put",
		 '.', "outputDecimal",
		 ',', "outputCharacter",
		 '&', "inputDecimal",
		 '~', "inputCharacter",
		 'i', "inputFile",
		 'o', "outputFile",
		 '=', "execute",
		 'y', "getSysInfo",
		 '(', "loadSemantics",
		 ')', "unloadSemantics",
		 't', "splitIP")
));
// Tuple!('x', "blaa") -> Tuple!("'x'", `"blaa"`)
private template WrapForCasing(ins...) {
	static if (ins.length) {
		static assert (ins.length > 1, "WrapForCasing :: odd list");

		alias Tuple!(
			"'" ~ EscapeForChar!(ins[0]) ~ "'",
			Wrap               !(ins[1]),
			WrapForCasing      !(ins[2..$])
		) WrapForCasing;
	} else
		alias ins WrapForCasing;
}

template StdInstructions() {

import tango.io.device.File     : File;
import tango.io.device.FileMap  : FileMap;
import tango.io.stream.Buffered : BufferedOutput;
import tango.math.Math          : max;
import tango.text.Util          : join;
import tango.time.Clock;

import tango.stdc.stdlib : system;

import ccbi.container;
import ccbi.fingerprint;
import ccbi.globals;
import ccbi.random;
import ccbi.space.space;

alias .Coords!(dim) Coords;

// The instructions are ordered according to the order in which they
// appear within the documentation of the Funge-98 standard.
// A comment has been added prior to each function so that one can grep
// for the instruction's name and thereby find it easily.

/+++++++ Program Flow +++++++/

// Direction Changing
// ------------------

// Go East, Go West, Go North, Go South
void goEast() {
	version (MODE)
		if (cip.mode & cip.HOVER)
			return ++cip.delta.x;

	reallyGoEast;
}
void goWest() {
	version (MODE)
		if (cip.mode & cip.HOVER)
			return --cip.delta.x;
	reallyGoWest;
}

static if (dim >= 2) {
void goNorth() {
	version (MODE)
		if (cip.mode & cip.HOVER)
			return --cip.delta.y;
	reallyGoNorth;
}
void goSouth() {
	version (MODE)
		if (cip.mode & cip.HOVER)
			return ++cip.delta.y;
	reallyGoSouth;
}
}

static if (dim >= 3) {
void goHigh() {
	version (MODE)
		if (cip.mode & cip.HOVER)
			return ++cip.delta.z;
	reallyGoHigh;
}
void goLow() {
	version (MODE)
		if (cip.mode & cip.HOVER)
			return --cip.delta.z;
	reallyGoLow;
}
}

void reallyGoEast () { cip.delta = InitCoords!( 1); }
void reallyGoWest () { cip.delta = InitCoords!(-1); }

static if (dim >= 2) {
void reallyGoNorth() { cip.delta = InitCoords!(0,-1); }
void reallyGoSouth() { cip.delta = InitCoords!(0, 1); }
}

static if (dim >= 3) {
void reallyGoHigh () { cip.delta = InitCoords!(0,0, 1); }
void reallyGoLow  () { cip.delta = InitCoords!(0,0,-1); }
}

// Go Away
void goAway() {
	switch (randomUpTo!(2*dim)()) {
		case 0: reallyGoEast (); break;
		case 1: reallyGoWest (); break;
	static if (dim >= 2) {
		case 2: reallyGoNorth(); break;
		case 3: reallyGoSouth(); break;
	}
	static if (dim >= 3) {
		case 4: reallyGoHigh (); break;
		case 5: reallyGoLow  (); break;
	}
		default: assert (false);
	}
}

static if (!befunge93) {

static if (dim >= 2) {

// Turn Right
void turnRight() {
	version (MODE)
		if (cip.mode & cip.SWITCH)
			cip.unsafeCell = '[';

	// x = cos(90) x - sin(90) y = -y
	// y = sin(90) x + cos(90) y =  x
	cell      x =  cip.delta.x;
	cip.delta.x = -cip.delta.y;
	cip.delta.y = x;
}

// Turn Left
void turnLeft() {
	version (MODE)
		if (cip.mode & cip.SWITCH)
			cip.unsafeCell = ']';

	// x = cos(-90) x - sin(-90) y =  y
	// y = sin(-90) x + cos(-90) y = -x
	cell      x = cip.delta.x;
	cip.delta.x = cip.delta.y;
	cip.delta.y = -x;
}

}

// Absolute Vector
void absoluteVector() {
	version (detectInfiniteLoops)
		if (cip.stack.empty && state.ips.length == 1)
			throw new InfiniteLoopException(
				"x instruction at " ~ cip.pos.toString(),
				"The lone IP has an empty stack: "
				"caught by the x with no means of escape...");
	popVector(cip.delta);
}

}

// Reverse
// Returns Request because it is commonly invoked as "return reverse;"
// Present for Befunge-93 because of the above usage
Request reverse() { cip.reverse; return Request.MOVE; }

// Flow Control
// ------------

// Trampoline
void trampoline() { cip.move(); }

// Stop
Request stop() { return Request.STOP; }

// No Operation
void noOperation() {}

static if (!befunge93) {

// Jump Forward
void jumpForward() { cip.move(cip.delta * cip.stack.pop); }

// Quit
Request quit() {
	returnVal = cip.stack.pop;
	return Request.QUIT;
}

// Iterate
Request iterate() {
	auto
		n = cip.stack.pop,
		pos = cip.pos;

	cip.move();

	auto r = Request.MOVE;

	// negative argument is undefined by spec, just ignore it
	if (n <= 0)
		return r;

	cip.gotoNextInstruction();
	auto i = cip.unsafeCell;

	// k executes its operand from where k is
	// and doesn't move past it
	cip.pos = pos;

	// optimization
	// many instructions have the same behaviour regardless of iteration
	// so they need to be done only once
	// or can be short-cut, like 'z' and '$'
	switch (i) {
		case '$':
			cip.stack.pop(n);
			return r;

		case ':': {
			// pop and n+1 because of the empty stack case
			auto c = cip.stack.pop;
			auto p = cip.stack.reserve(n + 1);
			p[0..n+1] = c;
			return r;
		}

		case '\\':
			with (*cip.stack) {
				auto a = pop, b = pop;
				if (n & 1)
					push(b, a);
				else
					push(a, b);
			}
			return r;

		case '0', '1', '2', '3', '4', '5', '6', '7', '8', '9': {
			auto p = cip.stack.reserve(n);
			p[0..n] = i - '0';
			return r;
		}

		case 'a', 'b', 'c', 'd', 'e', 'f': {
			auto p = cip.stack.reserve(n);
			p[0..n] = i - 'a';
			return r;
		}

		case 'm':
			static if (dim < 3)
				goto case 'r';
		case '|':
			static if (dim < 2)
				goto case 'r';
		case '_':
			cip.stack.pop(n-1);
			return executeStandard(i);

		case 'x':
			cip.stack.pop(dim * (n-1));
			absoluteVector();
			return r;

		case 'h', 'l':
			static if (dim < 3)
				goto case 'r';
		case 'v', '^':
			static if (dim < 2)
				goto case 'r';
		case '<', '>', 'n', '?', '@', 'q':
			return executeStandard(i);

		case '[':
			static if (dim < 2)
				goto case 'r';
			else {
				switch (n % 4) {
					case 0: break;
					case 1: turnLeft;  break;
					case 2: reverse;   break;
					case 3: turnRight; break;
				}
				return r;
			}

		case ']':
			static if (dim < 2)
				goto case 'r';
			else {
				switch (n % 4) {
					case 0: break;
					case 1: turnRight; break;
					case 2: reverse;   break;
					case 3: turnLeft;  break;
				}
				return r;
			}

		case '"':
			if (n & 1)
				toggleStringMode();
			return r;

		case 'r':
			if (n & 1)
				reverse();

		case 'z':
			return r;

		default: break;
	}

	if (isSemantics(i)) while (n--) r = executeSemantics(i);
	else                while (n--) r = executeStandard (i);

	return r;
}

}

// Decision Making
// ---------------

// Logical Not
void logicalNot() { cip.stack.push(!cip.stack.pop); }

// Greater Than
void greaterThan() {
	cell c = cip.stack.pop;

	cip.stack.push(cip.stack.pop > c);
}

// East-West If, North-South If
void eastWestIf  () { if (cip.stack.pop) goWest();  else goEast();  }

static if (dim >= 2)
void northSouthIf() { if (cip.stack.pop) goNorth(); else goSouth(); }

static if (!befunge93) {

static if (dim >= 3)
void highLowIf   () { if (cip.stack.pop) goHigh();  else goLow();   }

// Compare
static if (dim >= 2)
void compare() {
	cell b = cip.stack.pop,
	     a = cip.stack.pop;

	if (a < b)
		turnLeft();
	else if (a > b)
		turnRight();
}

}

/+++++++ Cell Crunching +++++++/

// Integers
// --------

// Push Zero - Push Niner
// see template PushNumber

// Add
void add()      { cip.stack.push(cip.stack.pop + cip.stack.pop); }

// Multiply
void multiply() { cip.stack.push(cip.stack.pop * cip.stack.pop); }

// Subtract
void subtract() {
	cell fst = cip.stack.pop,
		  snd = cip.stack.pop;
	cip.stack.push(snd - fst);
}

// Divide
void divide() {
	cell fst = cip.stack.pop,
		  snd = cip.stack.pop;

	if (fst)
		cip.stack.push(snd / fst);
	else static if (befunge93) {
		try {
			Sout.flush;
			Serr("CCBI :: division by zero encountered. Input wanted result: ");
			Serr.flush;
		} catch {
			return reverse;
		}
		reallyInputDecimal();
	} else
		cip.stack.push(0);
}

// Remainder
void remainder() {
	cell fst = cip.stack.pop,
		  snd = cip.stack.pop;

	if (fst)
		cip.stack.push(snd % fst);
	else static if (befunge93) {
		try {
			Sout.flush;
			Serr("CCBI :: modulo by zero encountered. Input wanted result: ");
			Serr.flush;
		} catch {
			return reverse;
		}
		reallyInputDecimal();
	} else
		cip.stack.push(0);
}

// Push Ten - Push Fifteen
// see 'Push Niner' above

// Strings
// -------

// Toggle Stringmode
void toggleStringMode() { cip.mode |= cip.STRING; }

static if (!befunge93) {

// Fetch Character
void fetchCharacter() {
	cip.move();
	cip.stack.push(cip.cell);
}

// Store Character
void storeCharacter() {
	cip.move();
	cip.cell = cip.stack.pop;
}

}

// Stack Manipulation
// ------------------

// Pop
void pop() { cip.stack.pop(1); }

// Duplicate
void duplicate() {
	// duplicating an empty stack should leave two zeroes
	// hence can't do push(top);
	auto c = cip.stack.pop;
	cip.stack.push(c, c);
}

// Swap
void swap() {
	auto c = cip.stack.pop;
	cip.stack.push(c, cip.stack.pop);
}

static if (!befunge93) {

// Clear Stack
void clearStack() { cip.stack.clear(); }

}

// Stack Stack Manipulation
// ------------------------

static if (!befunge93) {

// Begin Block
Request beginBlock() {
	version (MODE)
		if (cip.mode & cip.SWITCH)
			cip.unsafeCell = '}';

	try {
		if (!cip.stackStack) {
			cip.stackStack = new typeof(*cip.stackStack);
			*cip.stackStack = typeof(*cip.stackStack)(&stackStackStats, 1u);
			cip.stackStack.push(cip.stack);
		}

		auto stack = new typeof(*cip.stack);
		version (MODE)
			*stack = typeof(*stack)(
				cip.stack.isDeque, cip.stack.isDeque ? &dequeStats : &stackStats);
		else
			*stack = typeof(*stack)(&stackStats);

		cip.stackStack.push(stack);
	} catch {
		return reverse();
	}

	auto soss = cip.stack;
	auto toss = cip.stackStack.top;

	version (MODE) if (soss.isDeque)
		toss.deque.mode = soss.deque.mode;

	auto n = soss.pop;

	if (n > 0) {
		// Funge-98: "[The { instruction] copies [the] elements as a block, so
		// order is preserved."
		//
		// That's pretty clear even though it actually modifies the push/pop
		// order when queuemode != invertmode.
		//
		// No mode: [... 1,2,3] --> [... 1,2,3]
		// Mode QI: [1,2,3 ...] --> [1,2,3 ...]
		// Mode Q:  [1,2,3 ...] --> [... 1,2,3]
		// Mode I:  [... 1,2,3] --> [1,2,3 ...]
		auto p = toss.reserve(n);

		soss.mapFirstN(n, (cell[] a) {
			p[0 .. a.length] = a;
			p += a.length;
		},
		(size_t n) {
			p[0..n] = 0;
			p += n;
		});
		soss.pop(n);
	} else if (n < 0) {
		n = -n;
		soss.reserve(n)[0..n] = 0;
	}

	pushVector(cip.offset);

	cip.stack = toss;

	cip.move();
	cip.offset = cip.pos;

	return Request.NONE;
}

// End Block
void endBlock() {
	version (MODE)
		if (cip.mode & cip.SWITCH)
			cip.unsafeCell = '{';

	if (cip.stackCount == 1)
		return reverse();

	auto oldStack = cip.stackStack.pop;
	cip.stack     = cip.stackStack.top;

	version (MODE) if (cip.stack.isDeque)
		cip.stack.deque.mode = oldStack.deque.mode;

	auto n = oldStack.pop;

	popVector(cip.offset);

	if (n > 0) {
		// As in the { case, just with a different source and target stack.

		auto p = cip.stack.reserve(n);

		oldStack.mapFirstN(n, (cell[] a) {
			p[0 .. a.length] = a;
			p += a.length;
		},
		(size_t n) {
			p[0..n] = 0;
			p += n;
		});
		// Don't need to pop from oldStack as we're about to free it anyway

	} else if (n < 0)
		cip.stack.pop(-n);

	oldStack.free();
	delete oldStack;
}

// Stack under Stack
void stackUnderStack() {
	if (cip.stackCount == 1)
		return reverse();

	cell count = cip.stack.pop;

	auto tmp  = cip.stackStack.pop;
	auto soss = cip.stackStack.top;
	cip.stackStack.push(tmp);

	version (MODE) if (cip.stack.isDeque)
		soss.deque.mode = cip.stack.deque.mode;

	typeof(cip.stack) src, tgt;

	if (count > 0) {
		src = soss;
		tgt = cip.stack;
	} else if (count < 0) {
		count = -count;
		src = cip.stack;
		tgt = soss;
	} else
		return;

	version (MODE)
		auto mode = cip.stack.mode;
	else
		const mode = 0;

	switch (mode) {
		case 0:                        // [... 3,2,1] --> [... 1,2,3]
		case QUEUE_MODE | INVERT_MODE: // [1,2,3 ...] --> [3,2,1 ...]
		{
			auto p = tgt.reserve(count) + count - 1;

			src.mapFirstN(count, (cell[] a) {
				foreach (c; a)
					*p-- = c;
			},
			(size_t n) {
				p -= n;
				p[0..n] = 0;
			});
			src.pop(count);
			break;
		}

		case QUEUE_MODE:  // [1,2,3 ...] --> [... 1,2,3]
		case INVERT_MODE: // [... 3,2,1] --> [3,2,1 ...]
		{
			auto p = tgt.reserve(count);

			src.mapFirstN(count, (cell[] a) {
				p[0..a.length] = a;
				p += a.length;
			},
			(size_t n) {
				p[0..n] = 0;
				p += n;
			});
			src.pop(count);
			break;
		}
	}
}

}

/+++++++ Communications and Storage +++++++/

// Funge-Space Storage
// -------------------

// Get
void get() {
	cip.stack.push(state.space[popOffsetVector()]);
}

// Put
void put() {
	auto c = popOffsetVector();
	state.space[c] = cip.stack.pop;
}

// Standard Input/Output
// ---------------------

// Output Decimal
void outputDecimal() {
	auto n = cip.stack.pop;

	static if (!befunge93)
		version (TRDS)
			if (state.tick < ioAfter)
				return;

	try Sout(n);
	catch { return reverse; }

	cput(' ');
}

// Output Character
void outputCharacter() {
	auto c = cast(ubyte)cip.stack.pop;

	static if (!befunge93)
		version (TRDS)
			if (state.tick < ioAfter)
				return;

	cput(c);

	if (c == '\n') {
		try Sout.flush;
		catch { reverse; }
	}
}

// Input Decimal
void inputDecimal() {
	static if (!befunge93)
		version (TRDS)
			if (state.tick < ioAfter)
				return cip.stack.push(0);

	try Sout.flush(); catch {}

	reallyInputDecimal();
}
void reallyInputDecimal() {
	ubyte c;

	try {
		do c = cget();
		while (c < '0' || c > '9');
	} catch {
		return reverse();
	}

	cunget(c);

	cell n = 0;
	ubyte[ToString!(cell.min).length] s;
	size_t j;

	reading: for (;;) {
		try c = cget();
		catch { return cip.stack.push(n); }

		if (c < '0' || c > '9')
			break;

		// Overflow: can't read more chars
		if (n > n.max / 10)
			break;

		s[j++] = c;

		cell tmp = 0;
		foreach (i, ch; s[0..j]) {
			auto add = ipow(10, j-i-1) * (ch - '0');

			// Overflow: can't add add
			if (tmp > tmp.max - add)
				break reading;

			tmp += add;
		}
		n = tmp;
	}
	cunget(c);

	cip.stack.push(n);
}

// Input Character
void inputCharacter() {
	static if (!befunge93)
		version (TRDS)
			if (state.tick < ioAfter)
				return cip.stack.push('T');

	try Sout.flush(); catch {}

	ubyte c;

	try {
		c = cget();

		if (c == '\r') {
			if ((c = cget()) != '\n')
				cunget(c);
			c = '\n';
		}
	} catch {
		return reverse();
	}

	cip.stack.push(c);
}

// File Input/Output
// -----------------

static if (!befunge93) {

// Input File
void inputFile() {
	cell c;
	auto filename = popString();

	auto binary = cast(bool)(cip.stack.pop & 1);

	Coords
		// the offsets to where to put the file
		va = popOffsetVector(),
		// the size of the rectangle where the file is eventually put
		vb;

	Array file;
	try file = new FileMap(filename, File.ReadExisting);
	catch {
		try {
			scope intermediate = new File(filename);
			file = new Array(intermediate.load);
		} catch {
			return reverse();
		}
	}

	state.space.load(file, &vb, va, binary);

	vb -= va;
	++vb;

	pushVector(vb);
	pushVector(va);
}

// Output File
void outputFile() {
	auto filename = popString();

	// va is whence the file is read
	// vb is the corresponding ending offsets relative to va
	auto textFile = cast(bool)(cip.stack.pop & 1);
	Coords
		va = popOffsetVector(),
		vb = popVector();

	if (flags.sandboxMode)
		return reverse;

	version (TRDS)
		if (state.tick < ioAfter)
			return;

	static if (dim >= 3) if (vb.z < 0) return reverse;
	static if (dim >= 2) if (vb.y < 0) return reverse;
	                     if (vb.x < 0) return reverse;

	File f;
	try f = new typeof(f)(filename, f.WriteCreate);
	catch {
		return reverse();
	}
	auto file = new BufferedOutput(f);
	scope (exit) {
		file.flush.close;
		f.flush.close;
	}

	auto maxPt = va + vb;

	if (textFile) {
		// treat as linear text file, meaning...

		static if (dim == 3) auto toBeWritten = new char[][][](vb.z, vb.y, vb.x);
		static if (dim == 2) auto toBeWritten = new char[][]  (      vb.y, vb.x);
		static if (dim == 1) auto toBeWritten = new char[]    (            vb.x);

		const char[] X =
			"for (c.x = va.x; c.x < maxPt.x; ++c.x) {"
			"	static if (dim == 1) auto row = toBeWritten;"
			"	row[c.x - va.x] = cast(char)state.space[c];"
			"}";
		const char[] Y =
			"for (c.y = va.y; c.y < maxPt.y; ++c.y) {"
			"	static if (dim <= 2) auto rect = toBeWritten;"
			"	auto row = rect[c.y - va.y];"
			"	" ~ X ~
			"}";

		Coords c = void;

		static if (dim == 3) {
			for (c.z = va.z; c.z < maxPt.z; ++c.z) {
				auto rect = toBeWritten[c.z - va.z];

				mixin (Y);
			}
		} else static if (dim == 2)
			mixin (Y);
		else static if (dim == 1)
			mixin (X);

		static if (dim == 3) {

			char[][] lines;
			if (toBeWritten.length)
				lines = new typeof(lines)(
					2 * max(toBeWritten[0].length, toBeWritten[$-1].length));

			bool atEOF = true;
			auto l = toBeWritten.length;

			foreach_reverse (inout rect; toBeWritten) {

				// End Of Rectangle
				bool atEOR = true;
				auto l2 = rect.length;

				// ...see comments in OutputLinearRect...
				mixin (OutputLinearRect!("l2", "rect", "atEOR"));

				// ...and remove EOR before EOF.
				if (atEOF) {
					if (rect.length == 0)
						--l;
					else
						atEOF = false;
				}
			}
			toBeWritten.length = l;

			if (toBeWritten.length) try {
				foreach (row; toBeWritten[0])
					file.append(row).append(NewlineString);

				foreach (rect; toBeWritten[1..$]) {
					// put a form feed between rectangles, not after each one
					file.append(\f);

					foreach (row; rect)
						file.append(row).append(NewlineString);
				}
			} catch {
				reverse;
			}

		} else static if (dim == 2) {

			auto lines = new char[][](2 * toBeWritten.length);

			bool atEOF = true;
			auto l = toBeWritten.length;

			// ...see comments in OutputLinearRect.
			mixin (OutputLinearRect!("l", "toBeWritten", "atEOF"));

			try foreach (row; toBeWritten)
				file.append(row).append(NewlineString);
			catch {
				reverse;
			}

		} else static if (dim == 1) {
			// ...remove whitespace before EOL.

			// since this may be a 1000x1-type "row" with many line breaks
			// within, we have to treat each "sub-row" as well

			try foreach (line; LineSplitter(toBeWritten))
				file.append(stripr(line)).append(NewlineString);
			catch {
				reverse;
			}
		}
	} else try {
		// no flag: write everything in a block of size vb, including spaces
		// put form feeds and line breaks only between rects/lines
		state.space.binaryPut(file, va, maxPt);
	} catch {
		reverse;
	}
}
private template OutputLinearRect(char[] len, char[] rect, char[] atEOR) {
	const OutputLinearRect =
		"foreach_reverse (inout row; " ~rect~ ") {"

			// ..remove whitespace before EOL...

			// since this may be a 1000x1-type "row" with many line breaks
			// within, we have to treat each "sub-row" as well

		"	size_t i = 0;"
		"	foreach (line; LineSplitter(row)) {"
		"		if (i == lines.length)"
		"			lines.length = 2 * lines.length;"
		"		lines[i++] = stripr(line);"
		"	}"
		"	row = join(lines[0..i], NewlineString);"

			// ...and EOL before EOR...
		"	if (" ~atEOR~ ") {"
		"		if (row.length == 0)"
		"			--" ~len~ ";"
		"		else"
		"			" ~atEOR~ " = false;"
		"	}"
		"}"
		~rect~ ".length = " ~len~ ";"

		// we put an ending line break anyway; strip the last one
		"if (" ~rect~ ".length)"
		"	" ~rect~ "[$-1] = stripr(" ~rect~ "[$-1]);";
}

}

// System Execution
// ----------------

static if (!befunge93) {

// Execute
void execute() {
	auto cmd = popStringz();
	if (flags.sandboxMode) {
		cip.stack.push(cell.min);
		return reverse;
	}
	cip.stack.push(system(cmd));
}

}

// System Information Retrieval
// ----------------------------

static if (!befunge93) {

cell[7] sysInfoConstantTop =
	[ 0 // Marker that this array hasn't yet been verified: dim otherwise
	, PATH_SEPARATOR
	  // = is equivalent to C system()
	, 1
	, VERSION_NUMBER
	, HANDPRINT
	, cell.sizeof
	  // Unbuffered input is not being used
	  // = is implemented
	  // o is implemented
	  // i is implemented
	  // t is implemented
	, 0b01111 ];

// Sandbox mode modifies some of them; otherwise they'd be constant.
void computeConstantTop() {
	if (sysInfoConstantTop[0])
		return;

	sysInfoConstantTop[0] = dim;

	if (!flags.sandboxMode)
		return;

	// = is unavailable
	sysInfoConstantTop[$-5] = 0;

	// = and o are unavailable
	assert (sysInfoConstantTop[$-1] == 0b01111);
	sysInfoConstantTop[$-1] = 0b00011;
}

cell[] envCache, argsCache;

void computeArgsCache() { // {{{
	if (argsCache.length)
		return;

	size_t sz = 0;
	bool wasNull = false;
	foreach_reverse (farg; fungeArgs) {
		if (farg.length) {
			sz += farg.length;
			wasNull = false;

		// ignore consecutive null arguments
		} else if (!wasNull)
			wasNull = true;
		++sz;
	}

	argsCache.length = sz;
	auto q = argsCache.ptr;

	wasNull = false;
	foreach_reverse (farg; fungeArgs) {
		if (farg.length) {
			*q++ = 0;
			foreach_reverse (c; farg)
				*q++ = c;
			wasNull = false;

		} else if (!wasNull) {
			*q++ = 0;
			wasNull = true;
		}
	}
} // }}}
void computeEnvCache() { // {{{
	if (envCache.length)
		return;

	size_t sz = 0;
	auto env = environment(&sz);

	// Add env.length for the null terminators
	envCache.length = sz + env.length;
	auto q = envCache.ptr;

	foreach_reverse (var; env) {
		*q++ = 0;
		foreach_reverse (c; var)
			*q++ = c;
	}
} // }}}

private template SimpleVectorCases(char[] vec, cell offset, cell i = 0) {
	static if (i < dim)
		const SimpleVectorCases =
			"case " ~ToString!(offset+i)~ ":"
			"	return cip.stack.push(" ~vec~ ".v[$-1 - (arg - " ~ToString!(offset)~ ")]);"
			~ SimpleVectorCases!(vec, offset, i+1);
	else
		const SimpleVectorCases = "";
}
private template BoundsVectorCases(cell offset, cell i = 0) {
	static if (i < dim*2)
		const BoundsVectorCases = "case " ~ToString!(offset+i)~ ":"
			~ BoundsVectorCases!(offset, i+1);
	else
		const BoundsVectorCases = "{"
			"Coords beg = void, end = void;"
			"state.space.getTightBounds(beg, end);"
			"end -= beg;"
			"if (arg < " ~ToString!(offset + dim)~ ")"
			"	return cip.stack.push(beg.v[$-1 - (arg - " ~ToString!(offset)~ ")]);"
			"else"
			"	return cip.stack.push(end.v[$-1 - (arg - " ~ToString!(offset+dim)~ ")]);"
		"}";
}

// Get SysInfo
void getSysInfo() {
	auto arg = cip.stack.pop;

	if (arg <= 0) {
		// We're going to push everything: reserve space for it all and copy it
		// on

		auto oldStackSize = cip.stack.size;

		// Top 9 cells; 5 vectors; another 3 cells; at least one stack size;
		// command line arguments terminated by double null; environment
		// variables terminated by null
		const GUARANTEED_SIZE = 9 + 5*dim + 3 + 1 + 2 + 1;

		computeEnvCache();
		computeArgsCache();
		computeConstantTop();

		auto p = cip.stack.reserve(
			GUARANTEED_SIZE + (cip.stackCount - 1) +
			envCache.length + argsCache.length);

		auto origP = p;

		// Environment

		*p++ = 0;
		p[0..envCache.length] = envCache;
		p += envCache.length;

		// Command line arguments

		*p++ = 0;
		*p++ = 0;
		p[0..argsCache.length] = argsCache;
		p += argsCache.length;

		// Stack sizes

		if (cip.stackStack) {
			foreach (stack; &cip.stackStack.topToBottom)
				*p++ = stack.size;
			*(p-1) = oldStackSize;
		} else
			*p++ = oldStackSize;

		*p++ = cip.stackCount;

		// Time + date

		auto now = Clock.toDate();

		*p++ =
			now.time.hours   * 256 * 256 +
			now.time.minutes * 256       +
			now.time.seconds;
		*p++ =
			(now.date.year - 1900) * 256 * 256 +
			now.date.month         * 256       +
			now.date.day;

		// Bounds

		Coords beg = void, end = void;
		state.space.getTightBounds(beg, end);
		end -= beg;

		p[0..dim] = end.v; p += dim;
		p[0..dim] = beg.v; p += dim;

		// Cip info

		p[0..dim] = cip.offset.v; p += dim;
		p[0..dim] = cip.delta.v;  p += dim;
		p[0..dim] = cip.pos.v;    p += dim;

		*p++ = 0; // team number
		*p++ = cip.id;

		// Constant env info
		p[0..sysInfoConstantTop.length] = sysInfoConstantTop;

		// Cheap solution to invertmode
		version (MODE) if (cip.stack.mode & INVERT_MODE)
			origP[0 .. p + sysInfoConstantTop.length - origP].reverse;

		// And done.
		return;
	}

	// We know we're only going to push a single cell: find out which one it
	// will be.
	//
	// This code doesn't change with invertmode or queuemode: while the
	// description in the spec lends itself to all kinds of interpretations for
	// the cases of various modes, I'm going with the example "3y will act as if
	// only the handprint was pushed onto the stack".

	--arg;
	switch (arg) {
		static assert (sysInfoConstantTop.length == 7);
		case 0,1,2,3,4,5,6:
			computeConstantTop();
			return cip.stack.push(sysInfoConstantTop[$-arg-1]);

		case 7: return cip.stack.push(cip.id);
		case 8: return cip.stack.push(0); // team number

		mixin (SimpleVectorCases!("cip.pos",    9));
		mixin (SimpleVectorCases!("cip.delta",  9 + dim));
		mixin (SimpleVectorCases!("cip.offset", 9 + dim*2));

		mixin (BoundsVectorCases!(9 + dim*3));

		case 9 + dim*5, 9 + dim*5 + 1: {
			auto now = Clock.toDate();
			if (arg == 9 + dim*5)
				return cip.stack.push(
					(now.date.year - 1900) * 256 * 256 +
					now.date.month         * 256       +
					now.date.day);
			else
				return cip.stack.push(
					now.time.hours   * 256 * 256 +
					now.time.minutes * 256       +
					now.time.seconds);
		}

		case 9 + dim*5 + 2: return cip.stack.push(cip.stackCount);
		default: break;
	}
	arg -= 9 + dim*5 + 2 + 1;

	// Not one of the compile-time-known indices: try the runtime ones.

	// A stack size?

	if (arg < cip.stackCount) {
		// We might not have a stack stack, so special case the TOSS
		if (arg == 0)
			return cip.stack.push(cip.stack.size);
		else
			return cip.stack.push(cip.stackStack.at(arg).size);
	}

	arg -= cip.stackCount;

	// A character from a command line argument?

	computeArgsCache();

	if (arg < argsCache.length)
		return cip.stack.push(argsCache[$-1-arg]);

	arg -= argsCache.length;

	// In the double null terminator?
	if (arg < 2)
		return cip.stack.push(0);
	arg -= 2;

	// A character from an environment variable?

	computeEnvCache();

	if (arg < envCache.length)
		return cip.stack.push(envCache[$-1-arg]);

	arg -= envCache.length;

	// In the null terminator?
	if (arg == 0)
		return cip.stack.push(0);
	--arg;

	// Bigger than what we'd push: pick from the stack instead.

	if (arg < cip.stack.size)
		return cip.stack.push(cip.stack.at(cip.stack.size-1 - arg));

	// Picks from empty stack
	++cip.stack.stats.peekUnderflows;
	return cip.stack.push(0);
}

}

/+++++++ Extension and Customization +++++++/

// Fingerprints
// ------------

static if (!befunge93) {

private bool popFingerprint(out cell fingerprint) {
	auto n = cip.stack.pop;

	if (n <= 0)
		return false;

	if (flags.allFingsDisabled) {
		cip.stack.pop(n);
		return false;
	}

	fingerprint = 0;
	while (n--) {
		fingerprint <<= 8;
		fingerprint += cip.stack.pop;
	}
	return true;
}

// Load Semantics
Request loadSemantics() {
	version (MODE)
		if (cip.mode & cip.SWITCH)
			cip.unsafeCell = ')';

	cell fingerprint;
	if (!popFingerprint(fingerprint))
		return reverse();

	auto ins = instructionsOf(fingerprint);
	if (!ins)
		return reverse();

	foreach (i; ins)
		cip.requireSems(i - 'A', &semanticStats)
		   .push(Semantics(fingerprint, i));

	cip.stack.push(fingerprint, 1);

	// Call the constructor when we've already moved instead of before: TRDS
	// appreciates it
	cip.move;
	try {
		loadedFingerprint(fingerprint);
		return Request.NONE;
	} catch {
		// ctor failed
		foreach (i; ins)
			cip.semantics[i - 'A'].pop(1);
		cip.stack.pop(2);
		reverse;
		cip.move;
		return Request.MOVE;
	}
}

// Unload Semantics
void unloadSemantics() {
	version (MODE)
		if (cip.mode & cip.SWITCH)
			cip.unsafeCell = '(';

	cell fingerprint;
	if (!popFingerprint(fingerprint))
		return reverse();

	auto ins = instructionsOf(fingerprint);
	if (!ins)
		return reverse();

	bool rev = false;
	foreach (i; ins) {
		assert (isSemantics(i));

		auto sem = cip.semantics[i - 'A'];
		if (!sem || sem.empty)
			continue;

		try unloadedFingerprintIns(sem.pop.fingerprint);
		catch { rev = true; }
	}

	// One or more dtors failed
	if (rev)
		reverse;
}

}

/+++++++ Concurrent Funge-98 +++++++/

static if (!befunge93) {

// Split IP
Request splitIP() {
	++stats.ipForked;

	auto nip = cip.deepCopy();

	with (*nip) {
		id = ++state.currentID;

		version (IIPC)
			parentID = cip.id;

		reverse();
	}

	// Set cip here so the Request handler knows what to fork. Move the old cip
	// here, since the fork handler will obviously move the new cip (which is
	// also needed, to prevent nip from forkbombing—though the spec forgets to
	// mention that).
	cip.move();
	cip = nip;
	return Request.FORK;
}

}

} /+++++++ That's all, folks +++++++/
