// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2010-04-10 20:24:50

module ccbi.fingerprints.rcfunge98.arry;

import ccbi.fingerprint;

mixin (Fingerprint!(
	"ARRY",
	"Arrays",

	"A", "store   !(1)",
	"B", "retrieve!(1)",
	"C", "store   !(2)",
	"D", "retrieve!(2)",
	"E", "store   !(3)",
	"F", "retrieve!(3)",
	"G", "cip.stack.push(dim)"));

template ARRY() {

void retrieve(cell vdim)() {
	static if (vdim > dim)
		reverse();
	else {
		auto c = InitCoords!(0);
		with (*cip.stack) {
			static if (vdim >= 3) c.z = pop;
			static if (vdim >= 2) c.y = pop;
		                      	 c.x = pop;
		}
		auto arr = popVector();
		pushVector(arr);
		cip.stack.push(state.space[arr + c]);
	}
}

void store(cell vdim)() {
	static if (vdim > dim)
		reverse();
	else {
		auto c = InitCoords!(0);
		with (*cip.stack) {
			static if (vdim >= 3) c.z = pop;
			static if (vdim >= 2) c.y = pop;
		                      	 c.x = pop;
		}
		auto v = cip.stack.pop;
		auto arr = popVector();
		pushVector(arr);
		state.space[arr + c] = v;
	}
}

}
