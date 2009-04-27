// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:14:41

module ccbi.fingerprints.rcfunge98.indv;

import ccbi.fingerprint;

// 0x494e4456: INDV
// Pointer functions
// -----------------

mixin (Fingerprint!(
	"INDV",

	"G", "getNum",
	"P", "putNum",
	"V", "getVec",
	"W", "putVec"
));

// FIXME: decipher this and correct this

// get vector off of stack,,,,apply storage offset,,,,retrieve vector from
// funge-space,,,,apply storage offset,,,,retrieve vector from funge-space to
// stack,,,,,do not modify this last read vector...

// in all funcitons of INDV,,,,a vector is popped off the stack and the storage
// offset is applied,,,,that points to a vector in memory which is retrieved
// and the storage offset applied,,,,whatever data that points to is read as
// is....

// the final data read or written is not modified by the storage offset...
// only the 2 pointer vectors are...

template INDV() {

Coords getIndirect() {
	Coords c = popOffsetVector();

	Coords c2;
	static if (dim >= 3) { c2.z = space[c]; ++c.x; }
	static if (dim >= 2) { c2.y = space[c]; ++c.x; }
	                       c2.x = space[c];

	return c2;
}

void getNum() {
	cip.stack.push(space[getIndirect()]);
}

void putNum() {
	Coords c = getIndirect();
	space[c] = cip.stack.pop;
}

void getVec() {
	Coords c = getIndirect();

	c.x += dim-1;
	static if (dim >= 3) { cip.stack.push(space[c]); --c.x; }
	static if (dim >= 2) { cip.stack.push(space[c]); --c.x; }
	                       cip.stack.push(space[c]);
}

void putVec() {
	Coords c = getIndirect();

	                              space[c] = cip.stack.pop;
	static if (dim >= 2) { ++c.x; space[c] = cip.stack.pop; }
	static if (dim >= 3) { ++c.x; space[c] = cip.stack.pop; }
}

}
