// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:14:23

module ccbi.fingerprints.rcfunge98.fixp; private:

import math = tango.math.Math;
alias math.rndint round;

import ccbi.fingerprint;
import ccbi.ip;
import ccbi.random;
import ccbi.utils;

// 0x46495850: FIXP
// Some useful math functions
// --------------------------

static this() {
	mixin (Code!("FIXP"));

	fingerprints[FIXP]['A'] =& and;
	fingerprints[FIXP]['B'] =& acos;
	fingerprints[FIXP]['C'] =& cos;
	fingerprints[FIXP]['D'] =& rand;
	fingerprints[FIXP]['I'] =& sin;
	fingerprints[FIXP]['J'] =& asin;
	fingerprints[FIXP]['N'] =& neg;
	fingerprints[FIXP]['O'] =& or;
	fingerprints[FIXP]['P'] =& mulpi;
	fingerprints[FIXP]['Q'] =& sqrt;
	fingerprints[FIXP]['R'] =& pow;
	fingerprints[FIXP]['S'] =& signbit;
	fingerprints[FIXP]['T'] =& tan;
	fingerprints[FIXP]['U'] =& atan;
	fingerprints[FIXP]['V'] =& abs;
	fingerprints[FIXP]['X'] =& xor;
}

void and() { with (ip.stack) push(pop & pop); }
void or () { with (ip.stack) push(pop | pop); }
void xor() { with (ip.stack) push(pop ^ pop); }

void  sin() { ip.stack.push(cast(cell)round(10000 * math. sin(cast(real)ip.stack.pop / 10000  * (math.PI / 180.0)))); }
void  cos() { ip.stack.push(cast(cell)round(10000 * math. cos(cast(real)ip.stack.pop / 10000  * (math.PI / 180.0)))); }
void  tan() { ip.stack.push(cast(cell)round(10000 * math. tan(cast(real)ip.stack.pop / 10000  * (math.PI / 180.0)))); }
void asin() { ip.stack.push(cast(cell)round(10000 * math.asin(cast(real)ip.stack.pop / 10000) * (180.0 / math.PI) )); }
void acos() { ip.stack.push(cast(cell)round(10000 * math.acos(cast(real)ip.stack.pop / 10000) * (180.0 / math.PI) )); }
void atan() { ip.stack.push(cast(cell)round(10000 * math.atan(cast(real)ip.stack.pop / 10000) * (180.0 / math.PI) )); }

void rand   () { ip.stack.push(cast(cell)rand_up_to(cast(uint)ip.stack.pop)); }
void neg    () { ip.stack.push(-ip.stack.pop); }
void mulpi  () { ip.stack.push(cast(cell)round(math.PI * ip.stack.pop)); }
void sqrt   () { ip.stack.push(cast(cell)round(math.sqrt(cast(real)ip.stack.pop))); }
void abs    () { ip.stack.push(cast(cell)math.abs(cast(int)ip.stack.pop)); }

static assert (cell.sizeof == int.sizeof, "Change abs function in FIXP");

void signbit() { auto n = ip.stack.pop; ip.stack.push(n > 0 ? 1 : (n < 0 ? -1 : 0)); }

void pow() {
	auto b = ip.stack.pop, a = ip.stack.pop;

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

	ip.stack.push(a);
}
