// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2007-01-20 21:14:53

module ccbi.fingerprints.rcfunge98.strn;

import ccbi.fingerprint;

mixin (Fingerprint!(
	"STRN",
	"String functions",

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

// Reverse the top len cells on the stack
private void stringToGnirts(size_t len) {
	if (len < 2)
		return;

	// 0string -> 0gnirts
	//
	// Since we're not guaranteed to get a single contiguous array to reverse
	// from mapFirstNPushed, we have to instead gather them all up so that we
	// can reverse them as a whole.
	SmallArray!(cell[], 8) blocks;
	cip.stack.mapFirstNPushed(len, (cell[] a) { blocks ~= a; }, null);

	size_t len2 = len / 2;

	size_t begBI = 0, endBI = blocks.size - 1;
	cell[] begB = blocks[begBI], endB = blocks[endBI];
	size_t begBeg = 0, endEnd = endB.length - 1;

	for (;;) {
		auto tmp = begB[begBeg];
		begB[begBeg] = endB[endEnd];
		endB[endEnd] = tmp;

		if (!--len2)
			return;

		if (++begBeg >= begB.length) {
			begB = blocks[++begBI];
			begBeg = 0;
		}
		if (endEnd-- == 0) {
			endB = blocks[--endBI];
			endEnd = endB.length - 1;
		}
	}
}

void append() {
	auto top = popString().dup,
	     bot = popString();

	pushStringz(bot);
	pushString (top);
}

void compare() {
	auto s = popString().dup;

	cip.stack.push(ascii.compare(s, popString()));
}

// Done like so so that \n flushes
void display() { while (cip.stack.top) outputCharacter; cip.stack.pop(1); }

void search() {
	auto s = popString().dup;

	pushStringz(s[locatePattern(s, popString())..$]);
}

void get() {
	Coords c = popOffsetVector();

	Coords beg, end;
	state.space.getLooseBounds(beg, end);

	auto start = c;

	cip.stack.push(0);

	size_t len = 0;
	for (;;) {
		auto ch = cast(char)state.space[c];

		if (ch == 0)
			break;

		cip.stack.push(ch);
		++len;

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
				ucell toEnd   = cell.max - c.x + 1;
				ucell fromBeg = c2.x - cell.min;

				size_t neededLen = toEnd + fromBeg;

				// Wishful thinking...
				cip.stack.reserve(neededLen)[0..neededLen] = ' ';
				c.x = beg.x;
			} else
				throw new SpaceInfiniteLoopException(
					"STRN instruction G", c.toString(), InitCoords!(1).toString(),
					"String starting at " ~start.toString()~ " never terminates.");
		}
	}
	stringToGnirts(len);
}

void input() {
	cip.stack.push(0);

	version (TRDS)
		if (state.tick < ioAfter)
			return;

	Sout.flush;

	size_t len = 0;
	try {
		do {
			++len;
			cip.stack.push(cget());
		} while (cip.stack.top != '\n');
	} catch {
		cip.stack.popPushed(len);
		return reverse();
	}

	// lose the \r?\n
	cip.stack.popPushed(1);
	--len;
	if (cip.stack.topPushed == '\r') {
		cip.stack.popPushed(1);
		--len;
	}
	stringToGnirts(len);
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
	cip.stack.push(s.length);
}

void put() {
	Coords c = popOffsetVector();

	auto s = popStringWithZero();

	foreach (ch; s) {
		state.space[c] = ch;
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

	try cip.stack.push(parse(s));
	catch {
		reverse();
	}
}

}
