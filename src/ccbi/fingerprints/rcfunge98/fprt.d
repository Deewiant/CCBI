// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2010-04-10 20:42:48

module ccbi.fingerprints.rcfunge98.fprt;

import tango.stdc.stdarg;
import tango.stdc.stdio : snprintf, sprintf;

import ccbi.fingerprint;

mixin (Fingerprint!(
	"FPRT",
	"Formatted print",

	"D", "formatDouble",
	"F", "formatFloat",
	"I", "format32",
	"L", "format64",
	"S", "formatString"));

char[128] shortFmt;
char[]     longFmt;

char[] doFormat(T)(char* fmt, T x) {
	auto wanted = snprintf(shortFmt.ptr, shortFmt.length, fmt, x);

	if (wanted < shortFmt.length)
		return shortFmt[0..wanted];

	longFmt.length = wanted;

	sprintf(longFmt.ptr, fmt, x);
	return longFmt;
}

template FPRT() {

private union Double {
	double d;
	     static if (cell.sizeof == 4) align (1) struct { cell h, l; }
	else static if (cell.sizeof == 8) cell c;
	else static assert (false);
}
static assert (Double.sizeof == double.sizeof);

void formatDouble() {
	Double d;
	static if (cell.sizeof == 4) {
		d.l = cip.stack.pop;
		d.h = cip.stack.pop;
	} else
		d.c = cip.stack.pop;
	pushStringz(doFormat(popStringz(), d.d));
}
void formatFloat() {
	int i = cip.stack.pop();
	pushStringz(doFormat(popStringz(), *cast(float*)&i));
}
void format32() {
	int i = cip.stack.pop();
	pushStringz(doFormat(popStringz(), i));
}
void format64() {
	long i = cip.stack.pop();
	long j = cip.stack.pop();
	pushStringz(doFormat(popStringz(), j << 32 | i));
}
void formatString() {
	auto s = popStringWithZero().dup;
	pushStringz(doFormat(popStringz(), s.ptr));
}

}
