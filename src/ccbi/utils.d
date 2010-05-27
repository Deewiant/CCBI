// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2007-01-18 19:22:20

module ccbi.utils;

import tango.stdc.string : memmove;
import tango.text.Util   : delimit, join;

import ccbi.cell;

struct AnamnesicRing(T, ubyte N) {
	static assert (N > 0);
private:
	T[N] ring = void;
	ubyte pos = 0;
	bool full = false;

public:
	void push(T t) {
		if (pos == N) {
			full = true;
			pos = 0;
		}
		ring[pos++] = t;
	}

	ubyte read(T[] ts)
	in {
		assert (ts.length == N);
	} body {
		auto pos2 = pos == N ? 0 : pos;

		if (full) {
			ts[0 .. N - pos2] = ring[pos2..N];
			ts[N - pos2 .. $] = ring[0..pos2];
		} else
			ts[0..pos] = ring[0..pos];

		return size();
	}

	ubyte size() { return full ? N : pos; }

	const ubyte CAPACITY = N;
}

void removeAt(T)(inout T[] a, size_t i)
in {
  assert (i < a.length);
} body {
  if (i < a.length - 1)
    memmove(&a[i], &a[i+1], (a.length - (i+1)) * a[i].sizeof);

  a.length = a.length - 1;
}

char[] unwords(char[][] s) { return s.join(" "); }
char[][] words(char[]   s) {
	auto ws = s.delimit(" ");
	size_t n = 0;
	foreach (w; ws)
		if (w.length)
			ws[n++] = w;
	return ws[0..n];
}

bool isSemantics(cell i) { return i <= 'Z' && i >= 'A'; }

template Utils() {

import tango.stdc.string : strlen;

alias .Coords!(dim) Coords;

void cput(ubyte c) {
	if (!cputDirect(c))
		reverse;
}
bool cputDirect(ubyte c) {
	try return Sout.write((&c)[0..1]) == c.sizeof;
	catch { return false; }
}

void popVector(out Coords c) {
	with (c) {
		static if (dim >= 3) z = cip.stack.pop;
		static if (dim >= 2) y = cip.stack.pop;
		                     x = cip.stack.pop;
	}
}
void popOffsetVector(out Coords c) {
	popVector(c);
	static if (!befunge93)
		c += cip.offset;
}
Coords popVector() {
	Coords c;
	popVector(c);
	return c;
}
Coords popOffsetVector() {
	Coords c;
	popOffsetVector(c);
	return c;
}

void pushVector(Coords c) {
	static if (dim == 3)
		cip.stack.push(c.x, c.y, c.z);
	else static if (dim == 2)
		cip.stack.push(c.x, c.y);
	else static if (dim == 1)
		cip.stack.push(c.x);
	else
		static assert (false);
}
void pushOffsetVector(Coords c) {
	static if (!befunge93)
		c -= cip.offset;
	pushVector(c);
}

static if (!befunge93) {

static char[] popStringBuf;
static this() { popStringBuf = new char[80]; }

char[] popStringWithZero() {
	alias popStringBuf s;
	cell c;

	size_t j;
	do {
		if (j == s.length)
			s.length = 2 * s.length;

		s[j] = cast(char)cip.stack.pop;
	} while (s[j++]);

	return s[0..j];
}
char[] popString() {
	return popStringWithZero()[0..$-1];
}

char* popStringz() {
	return popStringWithZero().ptr;
}

void pushStringz(char[] s) {
	cip.stack.push(0);
	pushString(s);
}

void pushString(in char[] s) {
	auto p = cip.stack.reserve(s.length);

	version (MODE) if (cip.stack.mode & INVERT_MODE) {
		foreach (c; s)
			*p++ = c;
		return;
	}

	foreach_reverse (c; s)
		*p++ = c;
}

IP forkCip() {
	++stats.ipForked;

	auto nip = cip.deepCopy();
	with (*nip) {
		id = ++state.currentID;
		version (IIPC)
			parentID = cip.id;
	}
	return nip;
}
Request forkDone(IP nip) {
	// Set cip here so the Request handler knows what to fork. Move the old cip
	// here, since the fork handler will obviously move the new cip (which is
	// also needed, to prevent t from forkbombing—though the spec forgets to
	// mention that).
	cip.move();
	cip = nip;
	return Request.FORK;
}

}

}
