// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2007-01-20 21:14:41

module ccbi.fingerprints.rcfunge98.indv;

import ccbi.fingerprint;

mixin (Fingerprint!(
	"INDV",
	"Pointer functions",

	"G", "getNum",
	"P", "putNum",
	"V", "getVec",
	"W", "putVec"
));

template INDV() {

Coords getIndirect() {
	Coords c = popOffsetVector();

	Coords c2;
	static if (dim >= 3) { c2.z = state.space[c]; ++c.x; }
	static if (dim >= 2) { c2.y = state.space[c]; ++c.x; }
	                       c2.x = state.space[c];

	return c2 + cip.offset;
}

void getNum() {
	cip.stack.push(state.space[getIndirect()]);
}

void putNum() {
	Coords c = getIndirect();
	state.space[c] = cip.stack.pop;
}

void getVec() {
	Coords c = getIndirect();

	c.x += dim-1;
	static if (dim >= 3) { cip.stack.push(state.space[c]); --c.x; }
	static if (dim >= 2) { cip.stack.push(state.space[c]); --c.x; }
	                       cip.stack.push(state.space[c]);
}

void putVec() {
	Coords c = getIndirect();

	                              state.space[c] = cip.stack.pop;
	static if (dim >= 2) { ++c.x; state.space[c] = cip.stack.pop; }
	static if (dim >= 3) { ++c.x; state.space[c] = cip.stack.pop; }
}

}
