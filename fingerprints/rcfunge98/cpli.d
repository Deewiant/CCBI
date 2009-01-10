// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:13:38

module ccbi.fingerprints.rcfunge98.cpli; private:

import tango.io.Stdout : Stdout;
import tango.math.Math : sqrt;

import ccbi.fingerprint;
import ccbi.instructions : Out;
import ccbi.ip;

// 0x43504c49: CPLI
// Complex Integer extension
// -------------------------

static this() {
	mixin (Code!("CPLI"));

	fingerprints[CPLI]['A'] =& cplxAdd;
	fingerprints[CPLI]['D'] =& cplxDiv;
	fingerprints[CPLI]['M'] =& cplxMul;
	fingerprints[CPLI]['O'] =& cplxOut;
	fingerprints[CPLI]['S'] =& cplxSub;
	fingerprints[CPLI]['V'] =& cplxAbs;
}

void cplxAdd() {
	with (ip.stack) {
		cell bi = pop,
		     br = pop,
		     ai = pop,
		     ar = pop;
		push(ar + br, ai + bi);
	}
}

void cplxSub() {
	with (ip.stack) {
		cell bi = pop,
		     br = pop,
		     ai = pop,
		     ar = pop;
		push(ar - br, ai - bi);
	}
}

void cplxMul() {
	with (ip.stack) {
		cell bi = pop,
		     br = pop,
		     ai = pop,
		     ar = pop;
		push(ar*br - ai*bi, ar*bi + ai*br);
	}
}

void cplxDiv() {
	with (ip.stack) {
		cell bi = pop,
		     br = pop,
		     ai = pop,
		     ar = pop,
		     denom = bi*bi + br*br;
		if (denom)
			push(
				(ai*bi + ar*br) / denom,
				(ai*br - ar*bi) / denom);
		else
			push(0, 0);
	}
}

void cplxAbs() {
	with (ip.stack) {
		cell i = pop,
		     r = pop;
		push(cast(cell)sqrt(cast(real)(r*r + i*i)));
	}
}

void cplxOut() {
	with (ip.stack) {
		cell i = pop,
		     r = pop;
		Stdout(r);
		if (i > 0) {
			ubyte b = '+';
			Out.write(b);
		}
		Stdout(i)("i ");
	}
}
