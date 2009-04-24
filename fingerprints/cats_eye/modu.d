// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 20:32:07

module ccbi.fingerprints.cats_eye.modu; private:

import ccbi.fingerprint;
import ccbi.ip;

// 0x4d4f4455: MODU
// Modulo Arithmetic Extension
// ---------------------------

static this() {
	mixin (Code!("MODU"));

	fingerprints[MODU]['M'] =& signedResultModulo;
	fingerprints[MODU]['U'] =& unsignedResultModulo;
	fingerprints[MODU]['R'] =& cIntegerRemainder;
}

// signed-result modulo
void signedResultModulo() {
	static cell floordiv(cell x, cell y) {
		x /= y;
		if (x < 0)
			return x - cast(cell)1;
		else
			return x;
	}

	with (ip.stack) {
		cell y = pop,
		     x = pop;

		if (y) {
			push(x - floordiv(x, y) * y);
		} else
			push(0);
	}
}

// Sam Holden's unsigned-result modulo
void unsignedResultModulo() {
	/+ no idea who this Sam Holden is
	 + or if he has a special algorithm for this,
	 + but the following always gives an unsigned (positive) result...
	 +/

	with (ip.stack) {
		cell y = pop,
		     x = pop;

		if (y) {
			auto r = x % y;
			if (r < 0) {
				// http://graphics.stanford.edu/~seander/bithacks.html#IntegerAbs
				auto mask = y >> (typeof(y).sizeof*8 - 1);
				r += (y + mask) ^ mask;
			}
			push(r);
		} else
			push(0);
	}
}

// C-language integer remainder
void cIntegerRemainder() {
	/+ old C leaves negative modulo undefined
	 + but C99 defines it as the same sign as the dividend
	 + so that's what we're going with
	 +/

	with (ip.stack) {
		cell y = pop,
		     x = pop;

		if (y) {
			auto r = x % y;
			if ((x <= 0 && r <= 0) || (x >= 0 && r >= 0))
				push(r);
			else
				push(-r);
		} else
			push(0);
	}
}
