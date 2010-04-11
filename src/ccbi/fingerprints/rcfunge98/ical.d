// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2010-04-11 15:44:39

module ccbi.fingerprints.rcfunge98.ical;

import ccbi.fingerprint;

mixin (Fingerprint!(
	"ICAL",
	"Some Intercal-like functions",

	"A", "unary!(`&`)",
	"F", "forget",
	"I", "interleave",
	"N", "next",
	"O", "unary!(`|`)",
	"R", "resume",
	"S", "select",
	"X", "unary!(`^`)"));

template ICAL() {

void ipCtor() {
	if (!cip.nexting.length)
		cip.nexting.length = 80;
}
void ipDtor() {
	if (cip.nextingSz == 0)
		delete cip.nexting;
}

void unary(char[] op)() {
	ucell a = cip.stack.pop;
	ucell b;
	if (a > ushort.max)
		b = b >> 1 | b << (8*cell.sizeof - 1);
	else {
		auto as = cast(ushort)a;
		ushort bs = as >> 1 | as << 15;
		b = cast(ucell)bs;
	}
	cip.stack.push(mixin("a"~op~"b"));
}

void interleave() {
	// Algorithm adapted from:
	//
	// http://graphics.stanford.edu/~seander/bithacks.html#InterleaveBMN
	// (Credits to Sean Eron Anderson)

	const uint[] B = [0x55555555, 0x33333333, 0x0F0F0F0F, 0x00FF00FF];
	const uint[] S = [1, 2, 4, 8];

	uint b = cip.stack.pop & ushort.max;
	uint a = cip.stack.pop & ushort.max;

	a = (a | (a << S[3])) & B[3];
	a = (a | (a << S[2])) & B[2];
	a = (a | (a << S[1])) & B[1];
	a = (a | (a << S[0])) & B[0];

	b = (b | (b << S[3])) & B[3];
	b = (b | (b << S[2])) & B[2];
	b = (b | (b << S[1])) & B[1];
	b = (b | (b << S[0])) & B[0];

	cip.stack.push(a << 1 | b);
}

void select() {
	ucell b = cip.stack.pop;
	ucell a = cip.stack.pop;

	ucell n = 0;

	for (auto i = ubyte.max; b; b >>= 1, a >>= 1) {
		if ((b&1) == 0) continue;
		++i;
		if ((a&1) == 0) continue;
		n |= 1 << i;
	}
	cip.stack.push(n);
}

Request next() {
	if (cip.nextingSz == 79)
		return reverse;
	cip.nexting[cip.nextingSz++] = cip.pos;
	cip.pos = popOffsetVector();
	return Request.NONE;
}

void resume() {
	auto n = cip.stack.pop;
	if (n < 0)
		return reverse;
	if (n == 0)
		return;
	if (n > cip.nextingSz)
		return cip.nextingSz = 0;
	cip.nextingSz -= n;
	cip.pos = cip.nexting[cip.nextingSz];
}

void forget() {
	auto n = cip.stack.pop;
	if (n < 0)
		return reverse;
	if (n >= cip.nextingSz)
		return cip.nextingSz = 0;
	cip.nextingSz -= n;
}

}
