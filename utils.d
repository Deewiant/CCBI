// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-18 19:22:20

// Helpful utility functions and constants.
module ccbi.utils;

import tango.io.FileConduit;
import tango.io.Buffer;
import tango.sys.Environment;
import tango.stdc.stdlib;

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
	auto
		x = offsetX,
		y = offsetY;

	void put(ubyte t) { (*space)[x++, y] = cast(cell)t; }

	auto file = new Buffer(fc);
	auto input = new ubyte[0x400];
	bool lineBreak = false;

	reading: for (;;) {
		uint j = file.read(input);
		if (j == file.Eof)
			break;
		
		for (uint i = 0; i < j; ++i) {
			ubyte c = input[i];
			switch (c) {
				case '\r':
					if (binary)
						put(c);
					if (i < j-1) {
						if (input[i+1] == '\n')
							c = input[++i];
					} else {
						// got \r but no room in buffer
						// keep lineBreak as true and read more
						lineBreak = true;
						continue reading;
					}
				case '\n': lineBreak = true;
				default:   break;
			}

			// in binary mode, just put the EOL characters in Funge-Space as well
			if (lineBreak && !binary) {
				++y;
				x = offsetX;
				lineBreak = false;
			} else { // !lineBreak || binary
				if (y > *endY && c != ' ')
					*endY = y;

				static if (needBegX) {
					assert (!binary && !lineBreak);

					// yes, both have (c != ' ') but making it be checked
					// last speeds things up, it's almost always true
					if (x > *endX && c != ' ')
						*endX = x;
					else if (x < space.begX && c != ' ')
						space.begX = x;
				} else {
					// there's already something in Funge-Space; don't overwrite it with spaces
					if (c == ' ') {
						++x;
						continue;
					} else if (x > *endX && !lineBreak)
						*endX = x;

					lineBreak = false;
				}
				put(c);
			}
		}
	}
	file.close;
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

char[] s;
static this() { s = new char[80]; }

char[] popString(bool keepZero = false)() {
	cell c;

	size_t j;
	do {
		if (j == s.length)
			s.length = 2 * s.length;

		s[j] = ip.stack.pop;
	} while (s[j++]);

	auto ret = s[0 .. j - !keepZero];

	static if (keepZero)
		assert (!ret.length || ret[$-1] == 0);
	else
		assert (!ret.length || ret[$-1] != 0);

	return ret;
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
