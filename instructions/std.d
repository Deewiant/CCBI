// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-18 19:20:04

// The standard Befunge-98 instructions.
module ccbi.instructions.std;

import ccbi.templateutils;

// WORKAROUND: http://www.dsource.org/projects/dsss/ticket/175
import ccbi.random;

// WORKAROUND: good old http://d.puremagic.com/issues/show_bug.cgi?id=810
template PushNumber(uint n) {
	const PushNumber = "cip.stack.push(" ~ ToString!(n) ~ ")";
}

mixin (`template StdInsFunc(char c) {` ~
	Lookup!(
		"StdInsFunc", "c",
		`static assert (false, "No such standard instruction " ~c);`,

		P!( '>', "goEast"),
		P!( '<', "goWest"),
		P!( '^', "goNorth"),
		P!( 'v', "goSouth"),
		P!( 'h', "goHigh"),
		P!( 'l', "goLow"),
		P!( '?', "goAway"),
		P!( ']', "turnRight"),
		P!( '[', "turnLeft"),
		P!( 'r', "reverse"),
		P!( 'x', "absoluteVector"),
		P!( '#', "trampoline"),
		P!( '@', "stop"),
		P!( 'z', "noOperation"),
		P!( 'j', "jumpForward"),
		P!( 'q', "quit"),
		P!( 'k', "iterate"),
		P!( '!', "logicalNot"),
		P!( '`', "greaterThan"),
		P!( '_', "eastWestIf"),
		P!( '|', "northSouthIf"),
		P!( 'w', "compare"),
		P!( '0', PushNumber!(0)),
		P!( '1', PushNumber!(1)),
		P!( '2', PushNumber!(2)),
		P!( '3', PushNumber!(3)),
		P!( '4', PushNumber!(4)),
		P!( '5', PushNumber!(5)),
		P!( '6', PushNumber!(6)),
		P!( '7', PushNumber!(7)),
		P!( '8', PushNumber!(8)),
		P!( '9', PushNumber!(9)),
		P!( 'a', PushNumber!(10)),
		P!( 'b', PushNumber!(11)),
		P!( 'c', PushNumber!(12)),
		P!( 'd', PushNumber!(13)),
		P!( 'e', PushNumber!(14)),
		P!( 'f', PushNumber!(15)),
		P!( '+', "add"),
		P!( '*', "multiply"),
		P!( '-', "subtract"),
		P!( '/', "divide"),
		P!( '%', "remainder"),
		P!( '"', "toggleStringMode"),
		P!('\'', "fetchCharacter"),
		P!( 's', "storeCharacter"),
		P!( '$', "pop"),
		P!( ':', "duplicate"),
		P!('\\', "swap"),
		P!( 'n', "clearStack"),
		P!( '{', "beginBlock"),
		P!( '}', "endBlock"),
		P!( 'u', "stackUnderStack"),
		P!( 'g', "get"),
		P!( 'p', "put"),
		P!( '.', "outputDecimal"),
		P!( ',', "outputCharacter"),
		P!( '&', "inputDecimal"),
		P!( '~', "inputCharacter"),
		P!( 'i', "inputFile"),
		P!( 'o', "outputFile"),
		P!( '=', "execute"),
		P!( 'y', "getSysInfo"),
		P!( '(', "loadSemantics"),
		P!( ')', "unloadSemantics"),
		P!( 't', "splitIP")
	)
~ `}`);

template StdInstructions() {

import tango.io.Buffer;
import tango.io.device.FileConduit;
import tango.text.Util  : join, splitLines;
import tango.time.Clock;

import tango.stdc.stdlib : system;

import ccbi.container;
import ccbi.fingerprint;
import ccbi.globals;
import ccbi.ip;
import ccbi.random;
import ccbi.space;

alias .Coords!(dim) Coords;
alias .IP    !(dim) IP;

// WORKAROUND: http://d.puremagic.com/issues/show_bug.cgi?id=2326
final:

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
// Befunge-93

// Go East, Go West, Go North, Go South
void goEast () { if (cip.mode & cip.HOVER) ++cip.delta.x; else reallyGoEast;  }
void goWest () { if (cip.mode & cip.HOVER) --cip.delta.x; else reallyGoWest;  }
void goNorth() { if (cip.mode & cip.HOVER) --cip.delta.y; else reallyGoNorth; }
void goSouth() { if (cip.mode & cip.HOVER) ++cip.delta.y; else reallyGoSouth; }

void reallyGoEast () { cip.delta.x =  1; cip.delta.y =  0; }
void reallyGoWest () { cip.delta.x = -1; cip.delta.y =  0; }
void reallyGoNorth() { cip.delta.x =  0; cip.delta.y = -1; }
void reallyGoSouth() { cip.delta.x =  0; cip.delta.y =  1; }

// Go Away
void goAway() {
	switch (rand_up_to!(4)()) {
		case 0: reallyGoEast (); break;
		case 1: reallyGoWest (); break;
		case 2: reallyGoNorth(); break;
		case 3: reallyGoSouth(); break;
		default: assert (false);
	}
}

// Funge-98

// Turn Right
void turnRight() {
	if (cip.mode & cip.SWITCH)
		space[cip.pos] = '[';

	// x = cos(90) x - sin(90) y = -y
	// y = sin(90) x + cos(90) y =  x
	cell      x =  cip.delta.x;
	cip.delta.x = -cip.delta.y;
	cip.delta.y = x;
}

// Turn Left
void turnLeft() {
	if (cip.mode & cip.SWITCH)
		space[cip.pos] = ']';

	// x = cos(-90) x - sin(-90) y =  y
	// y = sin(-90) x + cos(-90) y = -x
	cell      x = cip.delta.x;
	cip.delta.x = cip.delta.y;
	cip.delta.y = -x;
}

// Reverse
// Returns Request because it is commonly invoked as "return reverse;"
Request reverse() { cip.reverse; return Request.MOVE; }

// Absolute Vector
void absoluteVector() { popVector(cip.delta); }

// Flow Control
// ------------
// Befunge-93

// Trampoline
void trampoline() { cip.move(); }

// Stop
Request stop() { return Request.STOP; }

// Funge-98

// No Operation
void noOperation() {}

// Jump Forward
void jumpForward() {
	cell n = cip.stack.pop;

	bool neg = n < 0;
	if (neg) {
		reverse();
		n *= -1;
	}

	while (n--)
		cip.move();

	if (neg)
		reverse();
}

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

	auto i = space[cip.pos];

	if (i == ' ' || i == ';') {
		cip.gotoNextInstruction();
		i = space.unsafeGet(cip.pos);
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

		case 'v', '^':
			static if (dim < 2)
				goto case 'r';

		case '<', '>', 'n', '?', '@', 'q':
			return executeStandard(i);

		case 'r':
			if (i & 1)
				reverse();

		case 'z':
			return r;

		default: break;
	}

	if (isSemantics(i)) {
		auto sem = i in cip.semantics;
		while (n--)
			r = executeSemantics(sem);
	} else
		while (n--)
			r = executeStandard(i);

	return r;
}

// Decision Making
// ---------------
// Befunge-93

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
void northSouthIf() { if (cip.stack.pop) goNorth(); else goSouth(); }

// Funge-98

// Compare
void compare() {
	cell b = cip.stack.pop,
	     a = cip.stack.pop;

	if (a < b)
		turnLeft();
	else if (a > b)
		turnRight();
}

/+++++++ Cell Crunching +++++++/

// Integers
// --------

// Befunge-93

// Push Zero - Push Niner
// see template PushNumber above

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

		// Note that division by zero = 0
		// In Befunge-93 it would ask the user what the result should be
		push(fst ? snd / fst : 0);
	}
}

// Remainder
void remainder() {
	with (cip.stack) {
		cell fst = pop,
		     snd = pop;

		// ditto above
		push(fst ? snd % fst : 0);
	}
}

// Push Ten - Push Fifteen
// see 'Push Niner' above

// Strings
// -------

// Befunge-93

// Toggle Stringmode
void toggleStringMode() { cip.mode |= cip.STRING; }

// Funge-98

// Fetch Character
void fetchCharacter() {
	cip.move();
	cip.stack.push(space[cip.pos]);
}

// Store Character
void storeCharacter() {
	cip.move();
	space[cip.pos] = cip.stack.pop;
}

// Stack Manipulation
// ------------------

// Befunge-93

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

// Funge-98

// Clear Stack
void clearStack() { cip.stack.clear(); }

// Stack Stack Manipulation
// ------------------------
// Funge-98

cell[] stdStackStackBuf;

// Begin Block
Request beginBlock() {
	alias stdStackStackBuf buf;

	if (cip.mode & cip.SWITCH)
		space[cip.pos] = '}';

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
		space[cip.pos] = '{';

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

/+++++++ Communications and Storage +++++++/

// Funge-Space Storage
// -------------------
// Befunge-93

// Get
void get() {
	cip.stack.push(space[popOffsetVector()]);
}

// Put
void put() {
	auto c = popOffsetVector();
	space[c] = cip.stack.pop;
}

// Standard Input/Output
// ---------------------
// Befunge-93

// Output Decimal
void outputDecimal() {
	auto n = cip.stack.pop;
	if (tick >= printAfter) {
		Sout(n);
		Cout.write(' ');
	}
}

// Output Character
void outputCharacter() {
	auto c = cast(ubyte)cip.stack.pop;
	if (tick >= printAfter) {
		if (c == '\n')
			Sout.newline;
		else
			Cout.write(c);
	}
}

// Input Decimal
void inputDecimal() {
	Stdout.flush();

	ubyte c;

	try {
		do c = cget();
		while (c < '0' || c > '9');
	} catch {
		return reverse();
	}

	cunget();

	cell n = 0;
	auto s = new typeof(c)[80];
	size_t j;

	try {
		reading: for (;;) {
			c = cget();

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

		// put back eaten char if it wasn't line break
		if (c == '\r') {
			if (cget() != '\n')
				cunget();
		} else if (c != '\n')
			cunget();
	} catch {
		return reverse();
	}

	cip.stack.push(n);
}

// Input Character
void inputCharacter() {
	Stdout.flush();

	ubyte c;

	try {
		c = cget();

		if (c == '\r') {
			c = '\n';
			if (cget() != '\n')
				cunget();
		}
	} catch {
		return reverse();
	}

	cip.stack.push(cast(cell)c);
}

// File Input/Output
// -----------------
// Funge-98

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

	FileConduit file;
	try file = new typeof(file)(filename);
	catch {
		return reverse();
	}

	space.load(file, &vb, va, binary, true);

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

	static if (dim >= 3) if (vb.z < 0) return reverse;
	static if (dim >= 2) if (vb.y < 0) return reverse;
	                     if (vb.x < 0) return reverse;

	// extend va and vb to 3 dimensions for simplicity
	auto
		vaE = va.extend(0),
		vbE = vb.extend(1);

	FileConduit f;
	try f = new typeof(f)(filename, WriteCreate);
	catch {
		return reverse();
	}
	auto file = new Buffer(f);
	scope (exit) {
		file.flush.close;
		f.flush.close;
	}

	auto max = vaE; max += vbE;

	if (flags & 1) {
		// treat as linear text file, meaning...

		// ...don't bother writing stuff that is only whitespace...
		static if (dim >= 3) if (max.z > space.end.z) max.z = space.end.z;
		static if (dim >= 2) if (max.y > space.end.y) max.y = space.end.y;
		                     if (max.x > space.end.x) max.x = space.end.x;

		auto arraySize = max; arraySize -= vaE;

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
					row[x - vaE.x] = space[c];
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
			foreach (rect; toBeWritten[0..$-1]) {
				foreach (row; rect)
					file.append(row).append(NewlineString);

				// put a form feed between rectangles, not after each one
				file.append(\f);
			}
			foreach (row; toBeWritten[$-1])
				file.append(row).append(NewlineString);
		}

	} else {
		// no flag: write everything in a block of size vb, including spaces
		// put form feeds and line breaks only between rects/lines
		space.binaryPut(file, vaE, max);
	}
}

// System Execution
// ----------------
// Funge-98

// Execute
void execute() {
	cip.stack.push(cast(cell)system(popStringz()));
}

// System Information Retrieval
// ----------------------------
// Funge-98

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

		auto relEnd = space.end; relEnd -= space.beg;

		pushVector(relEnd);
		pushVector(space.beg);
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

/+++++++ Extension and Customization +++++++/

// Fingerprints
// ------------
// Funge-98

// Load Semantics
void loadSemantics() {
	if (cip.mode & cip.SWITCH)
		space[cip.pos] = ')';

	auto n = cip.stack.pop;

	if (n <= 0)
		return reverse();

	if (!fingerprintsEnabled) {
		cip.stack.pop(n);
		return reverse();
	}

	cell fingerprint = 0;

	while (n--) {
		fingerprint <<= 8;
		fingerprint += cip.stack.pop;
	}

	if (auto init = fingerprint in fingerprintConstructors) {
		(*init)();

		if (fingerprint in fingerprintDestructors)
			++fingerprintLoaded[fingerprint];
	}

//	if (miniMode == Mini.ALL && loadMiniFunge(fingerprint))
//		goto mini;
//
/*	else*/ if (auto fing = fingerprint in fingerprints) {
		for (char c = 'A'; c <= 'Z'; ++c)
		if (auto func = (*fing)[c])
			cip.semantics[c].push(Semantics(BUILTIN, func));

//	} else if (miniMode == Mini.UNIMPLEMENTED && loadMiniFunge(fingerprint)) {
//		mini:
//
//		auto mini = fingerprint in minis;
//
//		for (char c = 'A'; c <= 'Z'; ++c)
//		if (auto mini = (*mini)[c])
//			cip.semantics[c].push(Semantics(MINI, &mini.instruction));
	} else
		return reverse();

	cip.stack.push(fingerprint, 1);
}

// Unload Semantics
void unloadSemantics() {
	if (cip.mode & cip.SWITCH)
		space[cip.pos] = '(';

	auto n = cip.stack.pop;

	if (n <= 0)
		return reverse();

	if (!fingerprintsEnabled) {
		cip.stack.pop(n);
		return reverse();
	}

	cell fingerprint = 0;

	while (n--) {
		fingerprint <<= 8;
		fingerprint += cip.stack.pop;
	}

	// FIXME: why a goto, why not just mess with the if condition
//	if (miniMode == Mini.ALL)
//		goto mini;

	auto implemented = fingerprint in fingerprints;

	if (implemented) {
		if (auto destroy = fingerprint in fingerprintDestructors)
			if (auto cnt = fingerprint in fingerprintLoaded)
				if (*cnt && !--*cnt)
					(*destroy)();

		for (char c = 'A'; c <= 'Z'; ++c)
		if ((*implemented)[c])
			cip.semantics[c].pop(1);
	} else {
//		mini:
//
//		auto mini = fingerprint in minis;
//
//		if (mini) {
//			for (char c = 'A'; c <= 'Z'; ++c)
//			if ((*mini)[c])
//				cip.semantics[c].pop(1);
//		} else
			reverse();
	}
}

/+++++++ Concurrent Funge-98 +++++++/

// Split IP
void splitIP() {
	ips ~= new IP!(dim)(cip);

	with (ips[$-1]) {
		id = ++currentID;

		parentID = cip.id;

		reverse();

		// move past the 't' or forkbomb
		move();
	}
}

} /+++++++ That's all, folks +++++++/
