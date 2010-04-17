// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2010-04-17 09:53:09

module ccbi.fingerprints.rcfunge98.imth;

import ccbi.fingerprint;

mixin (Fingerprint!(
	"IMTH",
	"Some integer math functions",

	"A", "average",
	"B", "abs",
	"C", "mul!(100)",
	"D", "decToZero",
	"E", "mul!(10000)",
	"F", "factorial",
	"G", "sign",
	"H", "mul!(1000)",
	"I", "incFromZero",
	"L", "shl",
	"N", "minMax!(`min`)",
	"R", "shr",
	"S", "sum",
	"T", "mul!(10)",
	"U", "printUnsigned",
	"X", "minMax!(`max`)",
	"Z", "mul!(-1)"));

template IMTH() {

import tango.math.Math : max, min;

void average() {
	auto n = cip.stack.pop;
	if (n < 0)
		return reverse;
	else if (n == 0)
		return cip.stack.push(0);

	cell sum = 0;
	cip.stack.mapFirstN(n, (cell[] a) { foreach (x; a) sum += x; }, (size_t){});
	cip.stack.pop(n);
	cip.stack.push(sum / n);
}
void sum() {
	auto n = cip.stack.pop;
	if (n < 0)
		return reverse;

	cell sum = 0;
	cip.stack.mapFirstN(n, (cell[] a) { foreach (x; a) sum += x; },
	                       (size_t z) { n += z; });
	cip.stack.pop(n);
	cip.stack.push(sum);
}

void abs()         { cip.stack.push(.abs(cip.stack.pop)); }
void mul(cell n)() { cip.stack.push(n *  cip.stack.pop); }

void decToZero() {
	auto n = cip.stack.pop;
	if (n > 0)
		--n;
	else if (n < 0)
		++n;
	cip.stack.push(n);
}
void incFromZero() {
	auto n = cip.stack.pop;
	if (n > 0)
		++n;
	else if (n < 0)
		--n;
	cip.stack.push(n);
}

void factorial() {
	cell f = 1;
	auto n = cip.stack.pop;
	if (n < 0)
		return reverse;
	while (n)
		f *= n--;
	cip.stack.push(f);
}

void sign() {
	auto n = cip.stack.pop;
	cip.stack.push(n != 0 | n >> n.sizeof * 8 - 1);
}

void shl() {
	auto c = cip.stack.pop;
	if (c < 0)
		cip.stack.push(cip.stack.pop >> -c % (c.sizeof * 8));
	else
		cip.stack.push(cip.stack.pop <<  c % (c.sizeof * 8));
}
void shr() {
	auto c = cip.stack.pop;
	if (c < 0)
		cip.stack.push(cip.stack.pop << -c % (c.sizeof * 8));
	else
		cip.stack.push(cip.stack.pop >>  c % (c.sizeof * 8));
}

void minMax(char[] f)() {
	auto n = cip.stack.pop;
	if (n-- <= 0)
		return reverse;
	cell m = cip.stack.pop;
	cip.stack.mapFirstN(n, (cell[] a) { foreach (x; a) m = mixin(f~"(m, x)"); },
	                       (size_t)   { m = mixin(f~"(m, 0)"); });
	cip.stack.pop(n);
	cip.stack.push(m);
}

void printUnsigned() {
	ucell n = cip.stack.pop;
	version (TRDS)
		if (state.tick < ioAfter)
			return;
	try Sout(n)(' '); catch { reverse; }
}

}
