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
template WrapForCasing(ins...) {
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

		case 'h', 'l':
			static if (dim < 3)
				goto case 'r';

		case 'v', '^':
			static if (dim < 2)
				goto case 'r';

		case '<', '>', 'n', '?', '@', 'q':
			return executeStandard(i);

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
void logicalNot() { with (cip.stack) push(cast(cell)!pop); }

// Greater Than
void greaterThan() {
	with (cip.stack) {
		cell c = pop;

		push(cast(cell)(pop > c));
	}
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
void add()      { with (cip.stack) push(pop + pop); }

// Multiply
void multiply() { with (cip.stack) push(pop * pop); }

// Subtract
void subtract() {
	with (cip.stack) {
		cell fst = pop,
		     snd = pop;
		push(snd - fst);
	}
}

// Divide
void divide() {
	with (cip.stack) {
		cell fst = pop,
		     snd = pop;

		if (fst)
			push(snd / fst);
		else static if (befunge93) {
			Sout.flush;
			Serr("CCBI :: division by zero encountered. Input wanted result: ");
			Serr.flush;
			reallyInputDecimal();
		} else
			push(0);
	}
}

// Remainder
void remainder() {
	with (cip.stack) {
		cell fst = pop,
		     snd = pop;

		if (fst)
			push(snd % fst);
		else static if (befunge93) {
			Sout.flush;
			Serr("CCBI :: modulo by zero encountered. Input wanted result: ");
			Serr.flush;
			reallyInputDecimal();
		} else
			push(0);
	}
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
	with (cip.stack) {
		auto c = pop;
		push(c, pop);
	}
}

static if (!befunge93) {

// Clear Stack
void clearStack() { cip.stack.clear(); }

}

// Stack Stack Manipulation
// ------------------------

static if (!befunge93) {

cell[] stdStackStackBuf;

// Begin Block
Request beginBlock() {
	alias stdStackStackBuf buf;

	if (cip.mode & cip.SWITCH)
		cip.unsafeCell = '}';

	try cip.stackStack.push(cip.newStack());
	catch {
		return reverse();
	}

	cip.stackStack.top.mode = cip.stack.mode;

	auto n = cip.stack.pop;

	if (n > 0) {
		if (n > buf.length)
			buf.length = n;

		// order must be preserved
		for (size_t i = n; i--;)
			buf[i] = cip.stack.pop;
		foreach (c; buf[0..n])
			cip.stackStack.top.push(c);
	} else
		while (n++)
			cip.stack.push(0);

	pushVector(cip.offset);

	cip.stack = cip.stackStack.top;

	cip.move();
	cip.offset = cip.pos;

	return Request.NONE;
}

// End Block
void endBlock() {
	alias stdStackStackBuf buf;

	if (cip.mode & cip.SWITCH)
		cip.unsafeCell = '{';

	if (cip.stackStack.size == 1)
		return reverse();

	auto oldStack  = cip.stackStack.pop;
	cip.stack      = cip.stackStack.top;
	cip.stack.mode = oldStack.mode;

	auto n = oldStack.pop;

	popVector(cip.offset);

	if (n > 0) {
		if (n > buf.length)
			buf.length = n;

		// order must be preserved
		for (size_t i = n; i--;)
			buf[i] = oldStack.pop;
		foreach (c; buf[0..n])
			cip.stack.push(c);
	} else
		cip.stack.pop(-n);
}

// Stack under Stack
void stackUnderStack() {
	if (cip.stackStack.size == 1)
		return reverse();

	cell count = cip.stack.pop;

	auto tmp  = cip.stackStack.pop;
	auto soss = cip.stackStack.top;
	cip.stackStack.push(tmp);

	soss.mode = cip.stack.mode;

	if (count > 0)
		while (count--)
			cip.stack.push(soss.pop);
	else if (count < 0)
		while (count++)
			soss.push(cip.stack.pop);
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

	// extend va and vb to 3 dimensions for simplicity
	auto
		vaE = va.extend(0),
		vbE = vb.extend(1);

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

	auto max = vaE + vbE;

	if (flags & 1) {
		// treat as linear text file, meaning...

		auto arraySize = max - vaE;

		auto toBeWritten = new char[][][](arraySize.z, arraySize.y, arraySize.x);

		Coords c;
		for (cell z = vaE.z; z < max.z; ++z) {
			auto rect = toBeWritten[z - vaE.z];

			static if (dim >= 3) c.z = z;

			for (cell y = vaE.y; y < max.y; ++y) {
				auto row = rect[y - vaE.y];

				static if (dim >= 2) c.y = y;

				for (cell x = vaE.x; x < max.x; ++x) {
					c.x = x;
					row[x - vaE.x] = cast(char)state.space[c];
				}
			}
		}

		bool atEOF = true;
		auto l = toBeWritten.length;

		foreach_reverse (inout rect; toBeWritten) {

			// End Of Rectangle
			bool atEOR = true;
			auto l2 = rect.length;

			foreach_reverse (inout row; rect) {

				// ...remove whitespace before EOL...

				// since this may be a 1000x1-type "row" with many line breaks
				// within, we have to treat each "sub-row" as well

				// TODO: don't use splitLines here, may split on UTF-8 line breaks
				// in a future Tango version, which we don't want, only \n \r \r\n
				auto lines = splitLines(row);
				foreach (inout line; lines)
					line = stripr(line);

				row = join(lines, NewlineString);

				// ...and EOL before EOR...
				if (atEOR) {
					if (row.length == 0)
						--l2;
					else
						atEOR = false;
				}
			}
			rect.length = l2;

			// we put an ending line break anyway
			if (rect.length)
				rect[$-1] = stripr(rect[$-1]);

			// ...and EOR before EOF
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

	} else {
		// no flag: write everything in a block of size vb, including spaces
		// put form feeds and line breaks only between rects/lines
		state.space.binaryPut(file, vaE, max);
	}
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

// Get SysInfo
void getSysInfo() {
	with (cip.stack) {
		auto arg = pop();

		auto oldStackSize = size;

		// environment

		push(0);
		foreach_reverse (v; environment())
			pushStringz(v);

		// command line arguments

		push(0, 0);

		bool wasNull = false;
		foreach_reverse (farg; fungeArgs) {
			if (farg.length) {
				pushStringz(farg);
				wasNull = false;

			// ignore consecutive null arguments
			} else if (!wasNull) {
				push(0);
				wasNull = true;
			}
		}

		// size of each stack on stack stack

		foreach (stack; &cip.stackStack.bottomToTop)
			push(cast(cell)stack.size);
		pop(1);
		push(
			cast(cell)oldStackSize,

		// size of stack stack

			cast(cell)cip.stackStack.size
		);

		// time + date

		auto now = Clock.toDate();

		push(
			cast(cell)(
				now.time.hours   * 256 * 256 +
				now.time.minutes * 256       +
				now.time.seconds),
			cast(cell)(
				(now.date.year - 1900) * 256 * 256 +
				now.date.month         * 256       +
				now.date.day));

		// the rest

		Coords beg, end;
		state.space.getTightBounds(beg, end);

		pushVector(end - beg);
		pushVector(beg);
		pushVector(cip.offset);
		pushVector(cip.delta);
		pushVector(cip.pos);

		push(
			// team number? not in the spec
			0,
			cip.id,
			dim,
			PATH_SEPARATOR,
			// = equivalent to C system()
			1,
			VERSION_NUMBER,
			HANDPRINT,
			cell.sizeof,
			// unbuffered input is not being used
			// = is implemented
			// o is implemented
			// i is implemented
			// t is implemented (this is Concurrent Befunge-98)
			0b01111
		);

		// phew, done pushing

		if (arg > 0) {
			auto diff = size - oldStackSize;

			// Handle the two cases differently for speed

			// Simpler, but breaks the stack abstraction and is slower with a
			// deque (where elementsBottomToTop() has to duplicate the whole
			// stack):
			//
			// auto pick = elementsBottomToTop()[size() - arg];
			// pop(size() - oldStackSize);
			// push(pick);

			if (arg < diff) {
				// Common case: the arg is one we pushed above
				// So pop up to it, copy it, pop the rest, and push it.
				pop(arg-1);

				auto tmp = pop;
				pop(size - oldStackSize);
				push(tmp);

			} else {
				// y as a 'pick' instruction
				// Pop what we pushed, pop up to the cell to be picked, push them
				// back and push the picked cell once more.
				pop(diff);
				arg -= diff;

				auto tmp = new cell[arg];
				foreach_reverse (inout c; tmp)
					c = pop;

				foreach (c; tmp)
					push(c);
				push(tmp[0]);
			}
		}
	}
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

	if (!flags.fingerprintsEnabled) {
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
		cip.semantics[i - 'A'].push(Semantics(fingerprint, i));
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
		try unloadedFingerprintIns(cip.semantics[i - 'A'].pop.fingerprint);
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

	state.ips ~= new typeof(this.cip)(cip);

	with (state.ips[$-1]) {
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
