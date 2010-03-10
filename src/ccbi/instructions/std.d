// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-18 19:20:04

// The standard Befunge-98 instructions.
module ccbi.instructions.std;

import tango.core.Tuple;

import ccbi.cell;
import ccbi.templateutils;
import ccbi.instructions.utils;

// WORKAROUND: http://www.dsource.org/projects/dsss/ticket/175
import ccbi.random;

// WORKAROUND: http://d.puremagic.com/issues/show_bug.cgi?id=810
// should be below StdInsFunc
// Tuple!('x', "blaa") -> Tuple!("'a'", `"blaa"`)
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

template StdInstructions() {

import tango.io.device.File     : File;
import tango.io.device.FileMap  : FileMap;
import tango.io.stream.Buffered : BufferedOutput;
import tango.text.Util          : join, splitLines;
import tango.time.Clock;

import tango.stdc.stdlib : system;

import ccbi.container;
import ccbi.fingerprint;
import ccbi.globals;
import ccbi.random;
import ccbi.space.space;

alias .Coords!(dim) Coords;

// WORKAROUND for D1: in D2, use __traits("compiles") in MakeSingleIns
// Bit of a hack to get PushNumber!() instructions to compile
// (Since it results in the otherwise invalid "Std.cip")
IP cip() { return this.cip; }

//import ccbi.mini.funge;
//import ccbi.mini.instructions : miniUnimplemented;
//import ccbi.mini.vars         : miniMode, Mini, warnings, inMini;

// The instructions are ordered according to the order in which they
// appear within the documentation of the Funge-98 standard.
// A comment has been added prior to each function so that one can grep
// for the instruction's name and thereby find it easily.

/+++++++ Program Flow +++++++/

// Direction Changing
// ------------------

// Go East, Go West, Go North, Go South
void goEast () { if (cip.mode & cip.HOVER) ++cip.delta.x; else reallyGoEast;  }
void goWest () { if (cip.mode & cip.HOVER) --cip.delta.x; else reallyGoWest;  }

static if (dim >= 2) {
void goNorth() { if (cip.mode & cip.HOVER) --cip.delta.y; else reallyGoNorth; }
void goSouth() { if (cip.mode & cip.HOVER) ++cip.delta.y; else reallyGoSouth; }
}

static if (dim >= 3) {
void goHigh() { if (cip.mode & cip.HOVER) ++cip.delta.z; else reallyGoHigh; }
void goLow () { if (cip.mode & cip.HOVER) --cip.delta.z; else reallyGoLow; }
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
	switch (rand_up_to!(2*dim)()) {
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
void absoluteVector() { popVector(cip.delta); }

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

	auto i = cip.cell;

	if (i == ' ' || i == ';') {
		cip.gotoNextInstruction();
		i = cip.unsafeCell;
	}

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
			p[0..n] = cast(cell)(i - '0');
			return r;
		}

		case 'a', 'b', 'c', 'd', 'e', 'f': {
			auto p = cip.stack.reserve(n);
			p[0..n] = cast(cell)(i - 'a');
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
			switch (n % 4) {
				case 0: break;
				case 1: turnLeft;  break;
				case 2: reverse;   break;
				case 3: turnRight; break;
			}
			return r;

		case ']':
			switch (n % 4) {
				case 0: break;
				case 1: turnRight; break;
				case 2: reverse;   break;
				case 3: turnLeft;  break;
			}
			return r;

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
void logicalNot() { cip.stack.push(cast(cell)!cip.stack.pop); }

// Greater Than
void greaterThan() {
	cell c = cip.stack.pop;

	cip.stack.push(cast(cell)(cip.stack.pop > c));
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
		Sout.flush;
		Serr("CCBI :: division by zero encountered. Input wanted result: ");
		Serr.flush;
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
		Sout.flush;
		Serr("CCBI :: modulo by zero encountered. Input wanted result: ");
		Serr.flush;
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
	if (cip.mode & cip.SWITCH)
		cip.unsafeCell = '}';

	try {
		if (!cip.stackStack) {
			cip.stackStack = new typeof(*cip.stackStack);
			*cip.stackStack = typeof(*cip.stackStack)(&stackStackStats, 1u);
			cip.stackStack.push(cip.stack);
		}

		auto stack = new typeof(*cip.stack);
		*stack = typeof(*stack)(
			cip.stack.isDeque, cip.stack.isDeque ? &dequeStats : &stackStats);

		cip.stackStack.push(stack);
	} catch {
		return reverse();
	}

	auto soss = cip.stack;
	auto toss = cip.stackStack.top;

	if (soss.isDeque)
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
	if (cip.mode & cip.SWITCH)
		cip.unsafeCell = '{';

	if (cip.stackCount == 1)
		return reverse();

	auto oldStack  = cip.stackStack.pop;
	cip.stack      = cip.stackStack.top;

	if (cip.stack.isDeque)
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

	if (cip.stack.isDeque)
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

	switch (cip.stack.mode) {
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

	static if (GOT_TRDS)
		if (state.tick < ioAfter)
			return;

	Sout(n);
	ubyte c = ' ';
	Cout.write(c);
}

// Output Character
void outputCharacter() {
	auto c = cast(ubyte)cip.stack.pop;

	static if (GOT_TRDS)
		if (state.tick < ioAfter)
			return;

	Cout.write(c);

	// TODO: maybe make this optional?
	if (c == '\n')
		Sout.flush;
}

// Input Decimal
void inputDecimal() {
	static if (GOT_TRDS)
		if (state.tick < ioAfter)
			return cip.stack.push(0);

	Sout.flush();

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
	auto s = new typeof(c)[80];
	size_t j;

	reading: for (;;) {
		try c = cget();
		catch { return cip.stack.push(n); }

		if (c < '0' || c > '9')
			break;

		// overflow: can't read more chars
		if (n > n.max / 10)
			break;

		if (j == s.length)
			s.length = 2 * s.length;

		s[j++] = c;

		cell tmp = 0;
		foreach (i, ch; s[0..j]) {
			auto add = ipow(10, j-i-1) * (ch - '0');

			// overflow: can't add add
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
	static if (GOT_TRDS)
		if (state.tick < ioAfter)
			return cip.stack.push('T');

	Sout.flush();

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

	cip.stack.push(cast(cell)c);
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
	auto flags = cip.stack.pop;
	Coords
		va = popOffsetVector(),
		vb = popVector();

	static if (GOT_TRDS)
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

	auto max = va + vb;

	if (flags & 1) {
		// treat as linear text file, meaning...

		static if (dim == 3) auto toBeWritten = new char[][][](vb.z, vb.y, vb.x);
		static if (dim == 2) auto toBeWritten = new char[][]  (      vb.y, vb.x);
		static if (dim == 1) auto toBeWritten = new char[]    (            vb.x);

		const char[] X =
			"for (c.x = va.x; c.x < max.x; ++c.x) {"
			"	static if (dim == 1) auto row = toBeWritten;"
			"	row[c.x - va.x] = cast(char)state.space[c];"
			"}";
		const char[] Y =
			"for (c.y = va.y; c.y < max.y; ++c.y) {"
			"	static if (dim <= 2) auto rect = toBeWritten;"
			"	auto row = rect[c.y - va.y];"
			"	" ~ X ~
			"}";

		Coords c = void;

		static if (dim == 3) {
			for (c.z = va.z; c.z < max.z; ++c.z) {
				auto rect = toBeWritten[c.z - va.z];

				mixin (Y);
			}
		} else static if (dim == 2)
			mixin (Y);
		else static if (dim == 1)
			mixin (X);

		static if (dim == 3) {

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

			if (toBeWritten.length) {
				foreach (row; toBeWritten[0])
					file.append(row).append(NewlineString);

				foreach (rect; toBeWritten[1..$]) {
					// put a form feed between rectangles, not after each one
					file.append(\f);

					foreach (row; rect)
						file.append(row).append(NewlineString);
				}
			}

		} else static if (dim == 2) {

			bool atEOF = true;
			auto l = toBeWritten.length;

			// ...see comments in OutputLinearRect.
			mixin (OutputLinearRect!("l", "toBeWritten", "atEOF"));

			foreach (row; toBeWritten)
				file.append(row).append(NewlineString);

		} else static if (dim == 1) {
			// ...remove whitespace before EOL.

			// since this may be a 1000x1-type "row" with many line breaks
			// within, we have to treat each "sub-row" as well

			// TODO: don't use splitLines here, may split on UTF-8 line breaks
			// in a future Tango version, which we don't want, only \n \r \r\n
			auto lines = splitLines(toBeWritten);
			foreach (line; lines)
				file.append(stripr(line)).append(NewlineString);
		}
	} else {
		// no flag: write everything in a block of size vb, including spaces
		// put form feeds and line breaks only between rects/lines
		state.space.binaryPut(file, va, max);
	}
}
private template OutputLinearRect(char[] len, char[] rect, char[] atEOR) {
	const OutputLinearRect =
		"foreach_reverse (inout row; " ~rect~ ") {"

			// ..remove whitespace before EOL...

			// since this may be a 1000x1-type "row" with many line breaks
			// within, we have to treat each "sub-row" as well

			// TODO: don't use splitLines here, may split on UTF-8 line breaks
			// in a future Tango version, which we don't want, only \n \r \r\n
		"	auto lines = splitLines(row);"
		"	foreach (inout line; lines)"
		"		line = stripr(line);"

		"	row = join(lines, NewlineString);"

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
	cip.stack.push(cast(cell)system(popStringz()));
}

}

// System Information Retrieval
// ----------------------------

static if (!befunge93) {

const cell[7] SYSINFO_CONSTANT_TOP =
	[ dim
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
				*q++ = cast(cell)c;
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
			*q++ = cast(cell)c;
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

		// Top 9 cells; 5 vectors; another 3 cells; at least one stack size;
		// command line arguments terminated by double null; environment
		// variables terminated by null
		const GUARANTEED_SIZE = 9 + 5*dim + 3 + 1 + 2 + 1;

		auto oldStackSize = cast(cell)cip.stack.size;

		auto minNeeded =
			GUARANTEED_SIZE + (cip.stackCount - 1) +
			envCache.length + argsCache.length;

		auto p = cip.stack.reserve(minNeeded);

		// Environment

		if (!envCache) {
			computeEnvCache();
			// Need to adjust by minNeeded since we haven't written that yet
			p = cip.stack.reserve(envCache.length) - minNeeded;
		}

		*p++ = 0;
		p[0..envCache.length] = envCache;
		p += envCache.length;

		// Command line arguments

		if (!argsCache) {
			computeArgsCache();
			// Ditto above minNeeded adjustment, but we did write the null
			// terminator which is part of that
			p = cip.stack.reserve(argsCache.length) - minNeeded + 1;
		}

		*p++ = 0;
		*p++ = 0;
		p[0..argsCache.length] = argsCache;
		p += argsCache.length;

		// Stack sizes

		if (cip.stackStack) {
			foreach (stack; &cip.stackStack.topToBottom)
				*p++ = cast(cell)stack.size;
			*(p-1) = oldStackSize;
		} else
			*p++ = oldStackSize;

		*p++ = cast(cell)cip.stackCount;

		// Time + date

		auto now = Clock.toDate();

		*p++ = cast(cell)(
			now.time.hours   * 256 * 256 +
			now.time.minutes * 256       +
			now.time.seconds);
		*p++ = cast(cell)(
			(now.date.year - 1900) * 256 * 256 +
			now.date.month         * 256       +
			now.date.day);

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
		p[0..SYSINFO_CONSTANT_TOP.length] = SYSINFO_CONSTANT_TOP;

		// And done.
		return;
	}

	// We know we're only going to push a single cell: find out which one it
	// will be.

	--arg;
	switch (arg) {
		static assert (SYSINFO_CONSTANT_TOP.length == 7);
		case 0,1,2,3,4,5,6: return cip.stack.push(SYSINFO_CONSTANT_TOP[$-arg-1]);
		case 7:             return cip.stack.push(cip.id);
		case 8:             return cip.stack.push(0); // team number

		mixin (SimpleVectorCases!("cip.pos",    9));
		mixin (SimpleVectorCases!("cip.delta",  9 + dim));
		mixin (SimpleVectorCases!("cip.offset", 9 + dim*2));

		mixin (BoundsVectorCases!(9 + dim*3));

		case 9 + dim*5, 9 + dim*5 + 1: {
			auto now = Clock.toDate();
			if (arg == 9 + dim*5)
				return cip.stack.push(cast(cell)(
					(now.date.year - 1900) * 256 * 256 +
					now.date.month         * 256       +
					now.date.day));
			else
				return cip.stack.push(cast(cell)(
					now.time.hours   * 256 * 256 +
					now.time.minutes * 256       +
					now.time.seconds));
		}

		case 9 + dim*5 + 2: return cip.stack.push(cast(cell)cip.stackCount);
		default: break;
	}
	arg -= 9 + dim*5 + 2 + 1;

	// Not one of the compile-time-known indices: try the runtime ones.

	// A stack size?

	if (arg < cip.stackCount) {
		// We might not have a stack stack, so special case the TOSS
		if (arg == 0)
			return cip.stack.push(cast(cell)cip.stack.size);
		else
			return cip.stack.push(cast(cell)cip.stackStack.at(arg).size);
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
	if (cip.mode & cip.SWITCH)
		cip.unsafeCell = ')';

	cell fingerprint;
	if (!popFingerprint(fingerprint))
		return reverse();

	auto ins = instructionsOf(fingerprint);
	if (!ins)
		return reverse();

	foreach (i; ins) {
		assert (isSemantics(cast(cell)i));

		auto sem = cip.semantics[i - 'A'];
		if (!sem) {
			sem = cip.semantics[i - 'A'] = new typeof(*sem);
			*sem = typeof(*sem)(&semanticStats, 2u);
		}

		sem.push(Semantics(fingerprint, i));
	}

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
		assert (isSemantics(cast(cell)i));

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

	state.ips ~= cip.deepCopy();

	with (*state.ips[$-1]) {
		id = ++state.currentID;

		static if (GOT_IIPC)
			parentID = cip.id;

		reverse();

		// move past the 't' or forkbomb
		move();
	}
	return Request.FORK;
}

}

} /+++++++ That's all, folks +++++++/
