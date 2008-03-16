// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:14:53

module ccbi.fingerprints.rcfunge98.strn; private:

import tango.io.Stdout            : Stdout;
import tango.text.Ascii           : compare;
import tango.text.Util            : locatePattern;
import tango.text.convert.Integer : format, parse;

import ccbi.fingerprint;
import ccbi.instructions : reverse;
import ccbi.ip;
import ccbi.space;
import ccbi.utils;

// 0x5354524e: STRN
// String functions
// ----------------

static this() {
	mixin (Code!("STRN"));

	fingerprints[STRN]['A'] =& append;
	fingerprints[STRN]['C'] =& compare;
	fingerprints[STRN]['D'] =& display;
	fingerprints[STRN]['F'] =& search;
	fingerprints[STRN]['G'] =& get;
	fingerprints[STRN]['I'] =& input;
	fingerprints[STRN]['L'] =& left;
	fingerprints[STRN]['M'] =& slice;
	fingerprints[STRN]['N'] =& length;
	fingerprints[STRN]['P'] =& put;
	fingerprints[STRN]['R'] =& right;
	fingerprints[STRN]['S'] =& itoa;
	fingerprints[STRN]['V'] =& atoi;
	
	fingerprintConstructors[STRN] =& ctor;
}

void append() {
	auto top = popString().dup,
	     bot = popString();

	pushStringz(bot);
	pushString (top);
}

void compare() {
	auto s = popString().dup;

	ip.stack.push(cast(cell)compare(s, popString()));
}

void display() { Stdout(popString()); }

void search() {
	auto s = popString().dup;

	pushStringz(s[locatePattern(s, popString())..$]);
}

// buffer for get() and input()
char[] buf;
void ctor() { buf = new char[80]; }

void get() {
	cellidx x, y;
	popVector(x, y);

	if (y > space.endY)
		return reverse();

	size_t i = 0;
	do {
		if (i == buf.length)
			buf.length = buf.length * 2;

		if (x > space.endX)
			return reverse();

		buf[i++] = space[x, y];

	} while (space.unsafeGet(x++, y) != 0);

	pushStringz(buf[0..i]);
}

void input() {
	Stdout.flush;

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
	auto n = ip.stack.pop,
	     s = popString();

	if (n < 0 || n > s.length)
		return reverse();

	pushStringz(s[0..n]);
}

void slice() {
	auto n = ip.stack.pop,
	     p = ip.stack.pop,
	     s = popString(),
	     e = p+n;

	if (p < 0 || n < 0 || e > s.length)
		return reverse();

	pushStringz(s[p..e]);
}

void length() {
	auto s = popString();

	pushStringz(s);
	ip.stack.push(cast(cell)s.length);
}

void put() {
	cellidx x, y;
	popVector(x, y);

	auto s = popString!(true);

	foreach (i, c; s)
		space[x+cast(cellidx)i, y] = cast(cell)c;
}

void right() {
	auto n = ip.stack.pop,
	     s = popString();

	if (n < 0 || n > s.length)
		return reverse();

	pushStringz(s[$-n..$]);
}

void itoa() {
	cell n = ip.stack.pop;

	static assert (cell.sizeof == 4 && cell.min < 0, "Need more than 11 chars here");
	char[11] buf;

	try pushStringz(format(buf, n));
	catch {
		reverse();
	}
}

void atoi() {
	auto s = popString();

	try ip.stack.push(cast(cell)parse(s));
	catch {
		reverse();
	}
}
