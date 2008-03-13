// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-18 19:20:04

// The standard Befunge-98 instructions.
module ccbi.instructions;

import tango.io.Buffer;
import tango.io.Console : Cin;
import tango.io.FileConduit;
import tango.io.Stdout  : Stdout;
import tango.text.Util  : join, splitLines;
import tango.time.Clock;

import tango.stdc.stdlib : system;

import ccbi.container;
import ccbi.fingerprint;
import ccbi.ip;
import ccbi.random;
import ccbi.space;
import ccbi.trace : tipSafe;
import ccbi.utils;

import ccbi.mini.instructions;
import ccbi.mini.funge;
import ccbi.mini.vars  : miniMode, Mini;

typeof(miniIns) instructions;

const cell
	HANDPRINT      = HexCode!("CCBI"),
	VERSION_NUMBER = 104; // remember to change ccbi.ccbi.VERSION_STRING too!

int returnVal;
char[][] fungeArgs;
bool fingerprintsEnabled = true;

version (Win32)
	const cell PATH_SEPARATOR = '\\';
else
	const cell PATH_SEPARATOR = '/';

// for TRDS: when jumping backwards in time, don't output until the jump target
// only needed because we rerun time from point 0 to do jumping
// strictly speaking, should affect a lot more than just ',' and '.'
// such as 'i', 'o', '&', '~', and other fingerprints with IO, but we're copying RC/Funge-98 here
typeof(ticks) printAfter;

static this() {
	instructions['>']  =& goEast;
  	instructions['<']  =& goWest;
	instructions['^']  =& goNorth;
	instructions['v']  =& goSouth;
	instructions['?']  =& goAway;
	instructions[']']  =& turnRight;
	instructions['[']  =& turnLeft;
	instructions['r']  =& reverse;
	instructions['x']  =& absoluteVector;
	instructions[' ']  =& ascii32;
	instructions['#']  =& trampoline;
	instructions['@']  =& stop;
	instructions[';']  =& jumpOver;
	instructions['z']  =& noOperation;
	instructions['j']  =& jumpForward;
	instructions['q']  =& quit;
	instructions['k']  =& iterate;
	instructions['!']  =& logicalNot;
	instructions['`']  =& greaterThan;
	instructions['_']  =& eastWestIf;
	instructions['|']  =& northSouthIf;
	instructions['w']  =& compare;
	instructions['0']  =& mixin (PushNumber!(0));
	instructions['1']  =& mixin (PushNumber!(1));
	instructions['2']  =& mixin (PushNumber!(2));
	instructions['3']  =& mixin (PushNumber!(3));
	instructions['4']  =& mixin (PushNumber!(4));
	instructions['5']  =& mixin (PushNumber!(5));
	instructions['6']  =& mixin (PushNumber!(6));
	instructions['7']  =& mixin (PushNumber!(7));
	instructions['8']  =& mixin (PushNumber!(8));
	instructions['9']  =& mixin (PushNumber!(9));
	instructions['a']  =& mixin (PushNumber!(10));
	instructions['b']  =& mixin (PushNumber!(11));
	instructions['c']  =& mixin (PushNumber!(12));
	instructions['d']  =& mixin (PushNumber!(13));
	instructions['e']  =& mixin (PushNumber!(14));
	instructions['f']  =& mixin (PushNumber!(15));
	instructions['+']  =& add;
	instructions['*']  =& multiply;
	instructions['-']  =& subtract;
	instructions['/']  =& divide;
	instructions['%']  =& remainder;
	instructions['"']  =& toggleStringMode;
	instructions['\''] =& fetchCharacter;
	instructions['s']  =& storeCharacter;
	instructions['$']  =& pop;
	instructions[':']  =& duplicate;
	instructions['\\'] =& swap;
	instructions['n']  =& clearStack;
	instructions['{']  =& beginBlock;
	instructions['}']  =& endBlock;
	instructions['u']  =& stackUnderStack;
	instructions['g']  =& get;
	instructions['p']  =& put;
	instructions['.']  =& outputDecimal;
	instructions[',']  =& outputCharacter;
	instructions['&']  =& inputDecimal;
	instructions['~']  =& inputCharacter;
	instructions['i']  =& inputFile;
	instructions['o']  =& outputFile;
	instructions['=']  =& execute;
	instructions['y']  =& getSysInfo;
	instructions['(']  =& loadSemantics;
	instructions[')']  =& unloadSemantics;
	instructions['t']  =& splitIP;

	// no concurrency + tracing, no need for ' ' and ';'
	auto ins = [
		'>', '<', '^', 'v', '?',
		']', '[',
		'r',
		'z',
		'#',
		'j',
		'!',
		'`',
		'_', '|', 'w',
		'0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
		'a', 'b', 'c', 'd', 'e', 'f',
		'+', '*', '-', '/', '%',
		'"',
		'$', ':', '\\', 'n',
		'.', ',',
		'&', '~',
		'y',
		'g', 'p'];

	foreach (i; ins)
		miniIns[i] = instructions[i];
}

// The instructions are ordered according to the order in which they
// appear within the documentation of the Funge-98 standard.
// A comment has been added prior to each function so that one can grep
// for the instruction's name and thereby find it easily.

/+++++++ Program Flow +++++++/

// Direction Changing
// ------------------
// Befunge-93

// Go East, Go West, Go North, Go South
void goEast () { ip.dx =  1; ip.dy =  0; }
void goWest () { ip.dx = -1; ip.dy =  0; }
void goNorth() { ip.dx =  0; ip.dy = -1; }
void goSouth() { ip.dx =  0; ip.dy =  1; }

// Go Away
void goAway() {
	switch (rand_up_to!(4)()) {
		case 0: goEast (); break;
		case 1: goWest (); break;
		case 2: goNorth(); break;
		case 3: goSouth(); break;
		default: assert (false);
	}
}

// Funge-98

// Turn Right
void turnRight() {
	// x = cos(90) x - sin(90) y = -y
	// y = sin(90) x + cos(90) y =  x
	cellidx x = ip.dx;
	ip.dx     = -ip.dy;
	ip.dy     = x;
}

// Turn Left
void turnLeft() {
	// x = cos(-90) x - sin(-90) y =  y
	// y = sin(-90) x + cos(-90) y = -x
	cellidx x = ip.dx;
	ip.dx     = ip.dy;
	ip.dy     = -x;
}

// Reverse
public void reverse() {
	ip.dx *= -1;
	ip.dy *= -1;
}

// Absolute Vector
void absoluteVector() { popVector(ip.dx, ip.dy); }

// Flow Control
// ------------
// Befunge-93

// Trampoline
void trampoline() { ip.move(); }

// Stop
void stop() { stateChange = State.STOPPING; }

// Space
void ascii32() {
	// no operation until next non-' ', takes no time
	do ip.move();
	while (space[ip.x, ip.y] == ' ');

	needMove = false;
}

// Funge-98

// No Operation
void noOperation() {}

// Jump Over
void jumpOver() {
	// no operation until next ';', takes no time
	do ip.move();
	while (space[ip.x, ip.y] != ';');
}

// Jump Forward
void jumpForward() {
	cell n = ip.stack.pop;

	bool neg = n < 0;
	if (neg) {
		reverse();
		n *= -1;
	}

	while (n--)
		ip.move();

	if (neg)
		reverse();
}

// Quit
void quit() {
	returnVal = ip.stack.pop;
	stateChange = State.QUITTING;
}

// Iterate
void iterate() {
	auto
		n  = ip.stack.pop,
		x  = ip.x,
		y  = ip.y,
		dx = ip.dx,
		dy = ip.dy;

	ip.move();

	// negative argument is undefined by spec, just ignore it
	if (n <= 0)
		return;

	auto i = space[ip.x, ip.y];

	if (i == ' ' || i == ';' || i == 'z')
		return;

	// special case optimization
	if (i == '$')
		return ip.stack.pop(n);

	// 0k^ doesn't execute ^
	// 1k^ does    execute ^
	/+ meaning: k executes its operand from where k is, but skips over its operand
	 + this, in turn, means that we have to get the next operand, go back and execute it,
	 + and if it didn't affect our delta or position, move past it
	 +/
	ip.x = x;
	ip.y = y;
	scope (success)
	if (ip.x == x && ip.y == y && ip.dx == dx && ip.dy == dy)
		ip.move();

	auto ins = instructions[i];

	// more optimization
	// many instructions have the same behaviour regardless of iteration
	// so they need to be done only once
	// arbitrary choice - just iterate if it's a really small number
	// haven't profiled to see where it'd start to matter
	if (n >= 10) switch (i) {
		case 'v', '^', '<', '>', 'n', '?', '@', 'q':
			return ins();
		case 'r':
			if (i & 1)
				reverse();
			return;
		default:
			if (ins is null)
				goto case 'r';
			break;
	}

	while (n--)
		ins();
}

// Decision Making
// ---------------
// Befunge-93

// Logical Not
void logicalNot() { with (ip.stack) push(cast(cell)!pop); }

// Greater Than
void greaterThan() {
	with (ip.stack) {
		cell c = pop;

		push(cast(cell)(pop > c));
	}
}

// East-West If, North-South If
void eastWestIf  () { if (ip.stack.pop) goWest();  else goEast();  }
void northSouthIf() { if (ip.stack.pop) goNorth(); else goSouth(); }

// Funge-98

// Compare
void compare() {
	cell b = ip.stack.pop,
	     a = ip.stack.pop;

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
template PushNumber(uint n) {
	const PushNumber = "push" ~ ToUtf8!(n);
}
template PushNumberFunc(uint n) {
	const PushNumberFunc = "void " ~ PushNumber!(n) ~ "() { ip.stack.push(" ~ ToUtf8!(n) ~ "); }";
}
template MixinFunc(uint from) {
	const MixinFunc = "mixin (PushNumberFunc!(" ~ ToUtf8!(from) ~ "));";
}
template PushNumberFuncs(uint from, uint to) {
	static assert (from <= to);

	static if (from == to)
		const PushNumberFuncs = MixinFunc!(from);
	else
		const PushNumberFuncs = MixinFunc!(from) ~ PushNumberFuncs!(from + 1, to);
}

mixin (PushNumberFuncs!(0, 9));

// Add
void add()      { with (ip.stack) push(pop + pop); }

// Multiply
void multiply() { with (ip.stack) push(pop * pop); }

// Subtract
void subtract() {
	with (ip.stack) {
		cell fst = pop,
		     snd = pop;
		push(snd - fst);
	}
}

// Divide
void divide() {
	with (ip.stack) {
		cell fst = pop,
		     snd = pop;

		// Note that division by zero = 0
		// In Befunge-93 it would ask the user what the result should be
		push(fst ? snd / fst : 0);
	}
}

// Remainder
void remainder() {
	with (ip.stack) {
		cell fst = pop,
		     snd = pop;

		// ditto above
		push(fst ? snd % fst : 0);
	}
}

// Push Ten - Push Fifteen
mixin (PushNumberFuncs!(10, 15));

// Strings
// -------

// Befunge-93

// Toggle Stringmode
void toggleStringMode() { ip.mode |= IP.STRING; }

// Funge-98

// Fetch Character
void fetchCharacter() {
	ip.move();
	ip.stack.push(space[ip.x, ip.y]);
}

// Store Character
void storeCharacter() {
	ip.move();
	space[ip.x, ip.y] = ip.stack.pop;
}

// Stack Manipulation
// ------------------

// Befunge-93

// Pop
void pop() { ip.stack.pop(1); }

// Duplicate
void duplicate() {
	// duplicating an empty stack should leave two zeroes
	// hence can't do push(top);
	auto c = ip.stack.pop;
	ip.stack.push(c, c);
}

// Swap
void swap() {
	with (ip.stack) {
		auto c = pop;
		push(c, pop);
	}
}

// Funge-98

// Clear Stack
void clearStack() { ip.stack.clear(); }

// Stack Stack Manipulation
// ------------------------
// Funge-98

// Begin Block
void beginBlock() {
	try ip.stackStack.push(ip.newStack());
	catch {
		return reverse();
	}

	ip.stackStack.top.mode = ip.stack.mode;

	cell n = ip.stack.pop;

	if (n > 0) {
		// order must be preserved
		auto elems = new cell[n];
		while (n--)
			elems[n] = ip.stack.pop;
		foreach (c; elems)
			ip.stackStack.top.push(c);
	} else if (n < 0)
		while (n++)
			ip.stack.push(0);

	pushVector(ip.offsetX, ip.offsetY);

	ip.move();

	ip.offsetX = ip.x;
	ip.offsetY = ip.y;

	needMove = false;

	ip.stack = ip.stackStack.top;
}

// End Block
void endBlock() {
	if (ip.stackStack.size == 1)
		return reverse();

	auto oldStack = ip.stackStack.pop;
	ip.stack      = ip.stackStack.top;
	ip.stack.mode = oldStack.mode;

	cell n = oldStack.pop;

	popVector(ip.offsetX, ip.offsetY);

	if (n > 0) {
		// order must be preserved
		auto elems = new cell[n];
		while (n--)
			elems[n] = oldStack.pop;
		foreach (c; elems)
			ip.stack.push(c);
	} else if (n < 0)
		ip.stack.pop(-n);
}

// Stack under Stack
void stackUnderStack() {
	if (ip.stackStack.size == 1)
		return reverse();

	cell count = ip.stack.pop;

	auto tmp  = ip.stackStack.pop;
	auto soss = ip.stackStack.top;
	ip.stackStack.push(tmp);

	soss.mode = ip.stack.mode;

	if (count > 0)
		while (count--)
			ip.stack.push(soss.pop);
	else if (count < 0)
		while (count++)
			soss.push(ip.stack.pop);
}

/+++++++ Communications and Storage +++++++/

// Funge-Space Storage
// -------------------
// Befunge-93

// Get
void get() {
	cellidx x, y;
	popVector!(true)(x, y);

	ip.stack.push(space[x, y]);
}

// Put
void put() {
	cellidx x, y;
	popVector!(true)(x, y);

	auto c = ip.stack.pop;

	if (y > space.endY)
		space.endY = y;
	else if (y < space.begY)
		space.begY = y;

	if (x > space.endX)
		space.endX = x;
	else if (x < space.begX)
		space.begX = x;

	space[x, y] = c;
}

// Standard Input/Output
// ---------------------
// Befunge-93

// Output Decimal
void outputDecimal() {
	auto n = ip.stack.pop;
	if (ticks >= printAfter)
		Stdout(n)(' ');
}

// Output Character
void outputCharacter() {
	auto c = cast(char)ip.stack.pop;
	if (ticks >= printAfter) {
		if (c == '\n')
			Stdout.newline;
		else
			Stdout(c);
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

			if (j == s.length)
				s.length = 2 * s.length;

			s[j++] = c;

			cell tmp = 0;
			foreach (i, ch; s[0..j]) {
				tmp += ipow(10u, j-i-1) * (ch - '0');

				if (tmp < 0)
					break reading;
			}

			// oops, overflow, stop here
			if (tmp < 0)
				break;

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

	ip.stack.push(n);
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

	ip.stack.push(cast(cell)c);
}

// File Input/Output
// -----------------
// Funge-98

// Input File
void inputFile() {
	cell c;
	auto filename = popString();

	auto binary = cast(bool)(ip.stack.pop & 1);

	// the offsets to where to put the file
	cellidx vaX, vaY,
	// the size of the rectangle where the file is eventually put
	        vbX, vbY;

	popVector!(true)(vaX, vaY);

	scope FileConduit file;
	try file = new typeof(file)(filename);
	catch {
		return reverse();
	}

	if (vaX < space.begX)
		space.begX = vaX;
	if (vaY < space.begY)
		space.begY = vaY;

	loadIntoFungeSpace!(false)(&space, file, &vbX, &vbY, vaX, vaY, binary);

	if (vbX > space.endX)
		space.endX = vbX;
	if (vbY > space.endY)
		space.endY = vbY;

	ip.stack.push(
		cast(cell)(vbX - vaX + 1), cast(cell)(vbY - vaY + 1),
		cast(cell)vaX, cast(cell)vaY
	);
}

// Output File
void outputFile() {
	cell c;
	auto filename = popString();

	// vaY and vaX are the offsets to whence to read the file
	// vbY and vbX are the corresponding ending offsets relative to vaY and vaX
	auto flags = ip.stack.pop;
	cellidx vaX, vaY,
	        vbX, vbY;

	popVector!(true)(vaX, vaY);
	popVector       (vbX, vbY);

	scope FileConduit f;
	try f = new typeof(f)(filename, WriteCreate);
	catch {
		return reverse();
	}
	scope file = new Buffer(f);
	scope (exit)
		file.close();

	auto maxX = vaX + vbX,
	     maxY = vaY + vbY;

	if (flags & 1) {
		// treat as linear text file, meaning...

		auto toBeWritten = new char[][](vbY, vbX);

		for (cellidx y = vaY; y < maxY; ++y)
		if (space.rowInRange(y))
		for (cellidx x = vaX; x < maxX; ++x) {
			if (space.cellInRange(x, y))
				toBeWritten[y - vaY][x - vaX] = cast(char)space.unsafeGet(x, y);
			else
				toBeWritten[y - vaY][x - vaX] = ' ';
		}

		// ...remove whitespace before EOL...
		foreach (inout row; toBeWritten) {

			/+ since this may be a 1000x1-type "row" with many line breaks within,
			   we have to treat each "sub-row" as well +/

			auto lines = splitLines(row);
			foreach (inout line; lines)
				line = stripr(line);

			row = join(lines, NewlineString);
		}

		// ...and EOL before EOF
		size_t l = toBeWritten.length;
		foreach_reverse (str; toBeWritten) {
			if (stripr(str).length == 0)
				--l;
			else
				break;
		}
		toBeWritten.length = l;

		// writeLine puts an ending line break anyway, so the last line needn't have one
		toBeWritten[$-1] = stripr(toBeWritten[$-1]);

		foreach (row; toBeWritten)
			file.append(row).append(NewlineString);

	} else {
		auto row = new char[vbX];

		for (cellidx y = vaY; y < maxY; ++y) {
			row[] = ' ';

			if (space.rowInRange(y))
			for (cellidx x = vaX; x < maxX; ++x)
			if (space.cellInRange(x, y))
				row[x - vaX] = cast(char)space.unsafeGet(x, y);

			file.append(row).append(NewlineString);
		}
	}
	file.flush;
}

// System Execution
// ----------------
// Funge-98

// Execute
void execute() {
	ip.stack.push(cast(cell)system(popStringz()));
}

// System Information Retrieval
// ----------------------------
// Funge-98

// Get SysInfo
void getSysInfo() {
	with (ip.stack) {
		auto arg = pop();

		auto oldStackSize = size;

		// environment

		auto env = environment();

		push(0);
		foreach (name; env.keys.sort.reverse) {
			auto value = env[name];

			push(0);

			foreach_reverse (c; value)
				push(cast(cell)c);

			push(cast(cell)'=');

			foreach_reverse (c; name)
				push(cast(cell)c);
		}

		// command line arguments

		push(0, 0);

		bool wasNull = false;
		foreach (farg; fungeArgs) {
			if (farg.length) {
				push(0);
				foreach_reverse (c; farg)
					push(cast(cell)c);
				wasNull = false;

			// ignore consecutive null arguments
			} else if (!wasNull) {
				push(0);
				wasNull = true;
			}
		}

		// size of each stack on stack stack

		foreach (stack; &ip.stackStack.bottomToTop)
			push(cast(cell)stack.size);
		pop(1);
		push(
			cast(cell)oldStackSize,

		// size of stack stack

			cast(cell)ip.stackStack.size
		);

		// time + date

		auto now = Clock.toDate();

		push(
			cast(cell)(  now.time.hours        * 256 * 256 + now.time.minutes * 256 + now.time.seconds),
			cast(cell)( (now.date.year - 1900) * 256 * 256 + now.date.month   * 256 + now.date.day)
		);

		// the rest

		push(
			cast(cell)(space.endX - space.begX), cast(cell)(space.endY - space.begY),
			cast(cell) space.begX,               cast(cell) space.begY,
			cast(cell)ip.offsetX,                cast(cell)ip.offsetY,
			cast(cell)ip.dx,                     cast(cell)ip.dy,
			cast(cell)ip.x,                      cast(cell)ip.y,
			// team number? not in the spec
			0,
			ip.id,
			// this is Befunge (2-dimensional)
			2,
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
			pop(arg-1);

			cell tmp = pop;

			pop(size - oldStackSize);

			push(tmp);
		}
	}
}

/+++++++ Extension and Customization +++++++/

// Fingerprints
// ------------
// Funge-98

// Load Semantics
void loadSemantics() {
	auto n = ip.stack.pop;

	if (n <= 0)
		return reverse();

	if (!fingerprintsEnabled) {
		ip.stack.pop(n);
		return reverse();
	}

	cell fingerprint = 0;

	while (n--) {
		fingerprint <<= 8;
		fingerprint += ip.stack.pop;
	}

	if (auto init = fingerprint in fingerprintConstructors) {
		(*init)();

		if (fingerprint in fingerprintDestructors)
			++fingerprintLoaded[fingerprint];
	}

	if (miniMode == Mini.ALL && loadMiniFunge(fingerprint))
		goto mini;

	else if (auto fing = fingerprint in fingerprints) {
		for (char c = 'A'; c <= 'Z'; ++c)
		if (auto func = (*fing)[c])
			ip.semantics[c].push(Semantics(BUILTIN, func));

	} else if (miniMode == Mini.UNIMPLEMENTED && loadMiniFunge(fingerprint)) {
		mini:

		auto mini = fingerprint in minis;

		for (char c = 'A'; c <= 'Z'; ++c)
		if (auto mini = (*mini)[c])
			ip.semantics[c].push(Semantics(MINI, &mini.instruction));
	} else
		return reverse();

	ip.stack.push(fingerprint, 1);
}

// Unload Semantics
void unloadSemantics() {
	auto n = ip.stack.pop;

	if (n <= 0)
		return reverse();

	if (!fingerprintsEnabled) {
		ip.stack.pop(n);
		return reverse();
	}

	cell fingerprint = 0;

	while (n--) {
		fingerprint <<= 8;
		fingerprint += ip.stack.pop;
	}

	if (miniMode == Mini.ALL)
		goto mini;

	auto implemented = fingerprint in fingerprints;

	if (implemented) {
		if (auto destroy = fingerprint in fingerprintDestructors)
			if (auto cnt = fingerprint in fingerprintLoaded)
				if (*cnt && !--*cnt)
					(*destroy)();

		for (char c = 'A'; c <= 'Z'; ++c)
		if ((*implemented)[c])
			ip.semantics[c].pop(1);
	} else {
		mini:

		auto mini = fingerprint in minis;

		if (mini) {
			for (char c = 'A'; c <= 'Z'; ++c)
			if ((*mini)[c])
				ip.semantics[c].pop(1);
		} else
			reverse();
	}
}

/+++++++ Concurrent Funge-98 +++++++/

// Split IP
void splitIP() { tipSafe({ips ~= IP.newIP();}); }

/+++++++ That's all, folks +++++++/
