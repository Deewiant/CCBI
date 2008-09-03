// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-18 19:22:20

module ccbi.utils;

import tango.stdc.string : memmove;
import tango.text.Util   : delimit, join;

import ccbi.cell;

void removeAt(T)(inout T[] a, size_t i)
in {
  assert (i < a.length);
} body {

  if (i < a.length - 1)
    memmove(&a[i], &a[i+1], (a.length - (i+1)) * a[i].sizeof);

  a.length = a.length - 1;
}

// remove range [i,j)
void removeAt(T)(inout T[] a, size_t i, size_t j)
in {
  assert (i < a.length && j <= a.length);
} body {

  if (j == haystack.length)
    a.length = a.length - i;
  else {
    memmove(&a[i], &a[j], (a.length - j) * a[i].sizeof);
    a.length = a.length - (j - i);
  }
}

char[][] words(char[]   s) { return s.delimit(" "); }
char[] unwords(char[][] s) { return s.join   (" "); }

// Thanks to Ben Hinkle at
// http://www.digitalmars.com/d/archives/digitalmars/D/learn/1625.html
void shallowCopy(Object a, Object b) {
	ClassInfo ci = a.classinfo;
	assert (ci is b.classinfo);

	auto
		src  = cast(void*)b,
		dest = cast(void*)a;

	size_t start = Object.classinfo.init.length;

	dest[start .. ci.init.length] = src[start .. ci.init.length];
}

bool isSemantics(cell i) { return i <= 'Z' && i >= 'A'; }

size_t findIndex(T)(T[] a, T v) {
	foreach (i, t; a)
		if (t is v)
			return i;
	return a.length;
}

// these all need cip
template Utils(cell dim) {

alias .Coords!(dim) Coords;

// WORKAROUND: http://d.puremagic.com/issues/show_bug.cgi?id=2326
final {
void popVector(out Coords c) {
	with (cip.stack) with (c) {
		static if (dim >= 3) z = cast(cell)pop;
		static if (dim >= 2) y = cast(cell)pop;
		                     x = cast(cell)pop;
	}
}
void popOffsetVector(out Coords c) {
	popVector(c);
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
	with (cip.stack) {
		static if (dim == 3)
			push(c.x, c.y, c.z);
		else static if (dim == 2)
			push(c.x, c.y);
		else static if (dim == 1)
			push(c.x);
		else
			static assert (false);
	}
}
void pushOffsetVector(Coords c) {
	c -= cip.offset;
	pushVector(c);
}
}

// TODO: this is not thread safe
static char[] popStringBuf;
static this() { popStringBuf = new char[80]; }

// WORKAROUND: http://d.puremagic.com/issues/show_bug.cgi?id=2326
final:

char[] popStringWithZero() {
	alias popStringBuf s;
	cell c;

	size_t j;
	do {
		if (j == s.length)
			s.length = 2 * s.length;

		s[j] = cip.stack.pop;
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
void pushStringz(char* s) {
	if (s) {
		while (*s++){}
		while (*s)
			cip.stack.push(cast(cell)*s--);
	} else
		cip.stack.push(0);
}

void pushString(in char[] s) {
	foreach_reverse (c; s)
		cip.stack.push(cast(cell)c);
}

}
