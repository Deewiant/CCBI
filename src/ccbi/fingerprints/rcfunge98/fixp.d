// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2007-01-20 21:14:23

module ccbi.fingerprints.rcfunge98.fixp;

import ccbi.fingerprint;

mixin (Fingerprint!(
	"FIXP",
	"Some useful math functions

      'B', 'C', 'I', 'J', 'P', 'Q', 'T', and 'U' round the number using the
                                                 current rounding mode.\n",

	"A", "and",
	"B", "acos",
	"C", "cos",
	"D", "rand",
	"I", "sin",
	"J", "asin",
	"N", "neg",
	"O", "or",
	"P", "mulpi",
	"Q", "sqrt",
	"R", "pow",
	"S", "signbit",
	"T", "tan",
	"U", "atan",
	"V", "abs",
	"X", "xor"
));

template FIXP() {

import ieee = tango.math.IEEE;
import math = tango.math.Math;

void pushFixp(real r) {
	if (ieee.isInfinity(r))
		cip.stack.push(ieee.signbit(r) ? cell.min : cell.max);
	else if (ieee.isNaN(r))
		reverse;
	else
		cip.stack.push(cast(cell)math.rndint(10000 * r));
}
real popFixp() {
	return cast(real)cip.stack.pop / 10000;
}

void and() { with (*cip.stack) push(pop & pop); }
void or () { with (*cip.stack) push(pop | pop); }
void xor() { with (*cip.stack) push(pop ^ pop); }

void  sin() { pushFixp(math. sin(popFixp()  * (math.PI / 180.0))); }
void  cos() { pushFixp(math. cos(popFixp()  * (math.PI / 180.0))); }
void  tan() { pushFixp(math. tan(popFixp()  * (math.PI / 180.0))); }
void asin() { pushFixp(math.asin(popFixp()) * (180.0 / math.PI) ); }
void acos() { pushFixp(math.acos(popFixp()) * (180.0 / math.PI) ); }
void atan() { pushFixp(math.atan(popFixp()) * (180.0 / math.PI) ); }

void rand() {
	auto c = cip.stack.pop;
	if (c < 0) {
		c = -c;
		cip.stack.push(cast(cell)-rand_up_to(c));
	} else
		cip.stack.push(cast(cell) rand_up_to(c));
}
void neg    () { cip.stack.push(-cip.stack.pop); }
void mulpi  () { cip.stack.push(cast(cell)math.rndint(math.PI * cip.stack.pop)); }
void abs    () { cip.stack.push(cast(cell)math.abs(cast(cell_base)cip.stack.pop)); }
void sqrt   () {
	auto r = cast(real)cip.stack.pop;
	if (r < 0)
		reverse;
	else
		cip.stack.push(cast(cell)math.rndint(math.sqrt(r)));
}

void signbit() { auto n = cip.stack.pop; cip.stack.push(n > 0 ? 1 : (n < 0 ? -1 : 0)); }

void pow() {
	auto b = cip.stack.pop, a = cip.stack.pop;

	// try to be smart instead of just casting to float and calculating it
	// which would probably be faster
	if (b > 0) {
		if (a)
			a = ipow(a, cast(uint)b);
	} else if (b < 0) {
		if (a == -1) {
			if (b & 1 == 0)
				a = 1;
		} else if (!a)
			a = cell.min; // 0^-n can be -inf
		else if (a != 1)
			a = 0;
	} else
		a = 1; // n^0, also 0^0: though indeterminate, it's defined thus in some contexts, so it's okay

	cip.stack.push(a);
}

}
