// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:14:53

module ccbi.fingerprints.rcfunge98.strn;

import ccbi.fingerprint;

// 0x5354524e: STRN
// String functions
// ----------------

mixin (Fingerprint!(
	"STRN",

	"A", "append",
	"C", "compare",
	"D", "display",
	"F", "search",
	"G", "get",
	"I", "input",
	"L", "left",
	"M", "slice",
	"N", "length",
	"P", "put",
	"R", "right",
	"S", "itoa",
	"V", "atoi"
));

template STRN() {

import ascii = tango.text.Ascii;
import tango.text.Util            : locatePattern;
import tango.text.convert.Integer : format, parse;

void append() {
	auto top = popString().dup,
	     bot = popString();

	pushStringz(bot);
	pushString (top);
}

void compare() {
	auto s = popString().dup;

	cip.stack.push(cast(cell)ascii.compare(s, popString()));
}

// Done like so so that \n flushes
void display() { while (cip.stack.top) outputCharacter; cip.stack.pop(1); }

void search() {
	auto s = popString().dup;

	pushStringz(s[locatePattern(s, popString())..$]);
}

// buffer for get() and input()
char[] buf;
void ctor() { buf = new char[80]; }
void dtor() { delete buf; }

void get() {
	Coords c = popOffsetVector();

	Coords beg, end;
	state.space.getLooseBounds(beg, end);

	auto start = c;

	size_t i = 0;
	for (;;) {
		auto ch = cast(char)state.space[c];

		if (ch == 0)
			break;

		if (i == buf.length)
			buf.length = buf.length * 2;

		buf[i++] = ch;
		++c.x;

		version (detectInfiniteLoops) if (c.x > end.x) {
			bool zeroLeft = false;
			auto c2 = c;
			for (c2.x = beg.x; c2.x < start.x; ++c2.x) {
				if (state.space[c2] == 0) {
					zeroLeft = true;
					break;
				}
			}

			if (zeroLeft) {
				auto toEnd   = cast(ucell)(cell.max - c.x + 1);
				auto fromBeg = cast(ucell)(c2.x - cell.min);

				size_t neededLen = toEnd + fromBeg;

				// Wishful thinking...
				if (buf.length < i + neededLen)
					buf.length = buf.length + neededLen;

				buf[i .. i+neededLen] = ' ';
				i += neededLen;
				c.x = beg.x;
			} else
				throw new SpaceInfiniteLoopException(
					"STRN instruction G", c.toString(), InitCoords!(1).toString(),
					"String starting at " ~start.toString()~ " never terminates.");
		}
	}
	pushStringz(buf[0..i]);
}

void input() {
	static if (GOT_TRDS)
		if (state.tick < ioAfter)
			return cip.stack.push(0);

	Sout.flush;

	size_t i = 0;
	try {
		do {
			if (i == buf.length)
				buf.length = buf.length * 2;

			buf[i] = cget();
		} while (buf[i++] != '\n');
	} catch {
		return reverse();
	}

	// lose the \r?\n
	if (buf[i-2] == '\r')
		--i;
	pushStringz(buf[0..i-1]);
}

void left() {
	auto n = cip.stack.pop,
	     s = popString();

	if (n < 0 || n > s.length)
		return reverse();

	pushStringz(s[0..n]);
}

void slice() {
	auto n = cip.stack.pop,
	     p = cip.stack.pop,
	     s = popString(),
	     e = p+n;

	if (p < 0 || n < 0 || e > s.length)
		return reverse();

	pushStringz(s[p..e]);
}

void length() {
	auto s = popString();

	pushStringz(s);
	cip.stack.push(cast(cell)s.length);
}

void put() {
	Coords c = popOffsetVector();

	auto s = popStringWithZero();

	foreach (ch; s) {
		state.space[c] = cast(cell)ch;
		++c.x;
	}
}

void right() {
	auto n = cip.stack.pop,
	     s = popString();

	if (n < 0 || n > s.length)
		return reverse();

	pushStringz(s[$-n..$]);
}

void itoa() {
	cell n = cip.stack.pop;

	char[ToString!(cell.min).length] buf;

	try pushStringz(format(buf, n));
	catch {
		reverse();
	}
}

void atoi() {
	auto s = popString();

	try cip.stack.push(cast(cell)parse(s));
	catch {
		reverse();
	}
}

}
