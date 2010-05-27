// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2010-05-27 11:25:12

module ccbi.fingerprints.rcfunge98.rand;

import ccbi.fingerprint;

mixin (Fingerprint!(
	"RAND",
	"Random Numbers

      The random number generator used is the same as the one used by other
      instructions such as ?, and thus S and T affect their behaviour as well."
      "\n"~
      (cell.sizeof > 4 ?"
      Only the lower 32 bits of the argument to S are used.\n" : ""),

	"I", "integer",
	"M", "max",
	"R", "floating",
	"S", "seed",
	"T", "seedAny"));

template RAND() {

import ccbi.random;

void integer() {
	with (*cip.stack) {
		auto n = cast(ucell)pop;
		if (n == 0)
			return reverse;
		push(randomUpTo(n));
	}
}
void max() { cip.stack.push(cell.max); }

union Union {
	float f;
	int c;
}
static assert (Union.sizeof == float.sizeof);
void floating() { Union u; u.f = random!(float); cip.stack.push(u.c); }

void seed()    { reseed(cast(uint)cip.stack.pop); }
void seedAny() { reseed(); }

}
