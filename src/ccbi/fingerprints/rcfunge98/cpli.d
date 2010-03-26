// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2007-01-20 21:13:38

module ccbi.fingerprints.rcfunge98.cpli;

import ccbi.fingerprint;

mixin (Fingerprint!(
	"CPLI",
	"Complex Integer extension",

	"A", "cplxAdd",
	"D", "cplxDiv",
	"M", "cplxMul",
	"O", "cplxOut",
	"S", "cplxSub",
	"V", "cplxAbs"
));

template CPLI() {

import tango.math.Math : sqrt;

void cplxAdd() {
	with (*cip.stack) {
		cell bi = pop,
		     br = pop,
		     ai = pop,
		     ar = pop;
		push(ar + br, ai + bi);
	}
}

void cplxSub() {
	with (*cip.stack) {
		cell bi = pop,
		     br = pop,
		     ai = pop,
		     ar = pop;
		push(ar - br, ai - bi);
	}
}

void cplxMul() {
	with (*cip.stack) {
		cell bi = pop,
		     br = pop,
		     ai = pop,
		     ar = pop;
		push(ar*br - ai*bi, ar*bi + ai*br);
	}
}

void cplxDiv() {
	with (*cip.stack) {
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
	with (*cip.stack) {
		cell i = pop,
		     r = pop;
		push(cast(cell)sqrt(cast(real)(r*r + i*i)));
	}
}

void cplxOut() {
	with (*cip.stack) {
		cell i = pop,
		     r = pop;

		version (TRDS)
			if (state.tick < ioAfter)
				return;

		try {
			Sout(r);
			if (i > 0 && !cputDirect('+'))
				return reverse;
			Sout(i)("i ");
		} catch {
			reverse;
		}
	}
}

}
