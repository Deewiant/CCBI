// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-18 19:22:20

// Helpful utility functions and constants.
module ccbi.utils;

import tango.io.FileConduit;
import tango.io.stream.TypedStream;
import tango.sys.Environment;

       import ccbi.ip;
       import ccbi.space;
public import ccbi.stdlib;

/+++ More directly Funge-related stuff +++/

// note that the endX/Y are absolute coordinates, not relative to offsetX/Y
// space.begY must be 0 after the first file load or we have an infinite-loop program (first row all spaces)
// space.begX must be found out, however
// so begY can be dealt with manually during an 'i' instruction, but begX has to be found during the first load
// (the 'i' instruction knows begX - it's on the IP's stack)
// hence the needBegX parameter
void loadIntoFungeSpace
(bool needBegX)
(
	Befunge98Space* space,
	FileConduit fc,
	cellidx* endX, cellidx* endY,
	cellidx offsetX = 0, cellidx offsetY = 0,
	bool binary = false
) in {
	assert (endX !is null);
	assert (endY !is null);
} body {
	cellidx x = offsetX,
	        y = offsetY;

	void put(ubyte t) { (*space)[x++, y] = cast(cell)t; }

	auto file = new TypedInput!(ubyte)(fc);
	scope (exit)
		file.close();

	bool lineBreak = false;

	for (uint ungot = 0x100;;) {
		ubyte c, d;

		if (ungot < 0x100) {
			c = cast(ubyte)ungot;
			ungot = 0x100;
		} else if (!file.read(c))
			break;

		if (c == '\r') {
			lineBreak = true;
			if (file.read(d) && d != '\n')
				ungot = d;

		} else if (c == '\n')
			lineBreak = true;
		else
			lineBreak = false;

		// in binary mode, just put the EOL characters in Funge-Space as well
		if (lineBreak && !binary) {
			++y;
			x = offsetX;
		} else {
			if (y > *endY && c != ' ')
				*endY = y;

			static if (needBegX) {
				// yes, both have (!lineBreak && c != ' ') but making them be checked
				// last speeds things up, they're almost always true
				if (x > *endX && !lineBreak && c != ' ')
					*endX = x;
				else if (x < space.begX && !lineBreak && c != ' ')
					space.begX = x;
			} else {
				// there's already something in Funge-Space; don't overwrite it with spaces
				if (c == ' ') {
					++x;
					continue;
				} else if (x > *endX && !lineBreak)
					*endX = x;
			}

			put(c);
			if (binary && lineBreak && d == '\n')
				put('\n');
		}
	}
}

void popVector(bool offset = false)(out cellidx x, out cellidx y) {
	with (ip.stack) {
		y = cast(cellidx)(pop + (offset ? ip.offsetY : 0));
		x = cast(cellidx)(pop + (offset ? ip.offsetX : 0));
	}
}
void pushVector(bool offset = false)(cellidx x, cellidx y) {
	with (ip.stack) {
		push(cast(cell)(x + (offset ? ip.offsetX : 0)));
		push(cast(cell)(y + (offset ? ip.offsetY : 0)));
	}
}

char[] popString(bool keepZero = false)() {
	auto s = new char[80];
	cell c;

	size_t j;
	do {
		if (j == s.length)
			s.length = 2 * s.length;

		s[j] = ip.stack.pop;
	} while (s[j++]);

	s.length = j - !keepZero;

	static if (keepZero)
		assert (!s.length || s[$-1] == 0);
	else
		assert (!s.length || s[$-1] != 0);

	return s;
}

char* popStringz() {
	return popString!(true).ptr;
}

void pushStringz(char[] s) {
	ip.stack.push(0);
	pushString(s);
}
void pushStringz(char* s) {
	if (s) {
		while (*s++){}
		while (*s)
			ip.stack.push(cast(cell)*s--);
	} else
		ip.stack.push(0);
}

void pushString(in char[] s) {
	foreach_reverse (c; s)
		ip.stack.push(cast(cell)c);
}
