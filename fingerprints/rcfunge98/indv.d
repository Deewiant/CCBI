// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:14:41

module ccbi.fingerprints.rcfunge98.indv; private:

import ccbi.fingerprint;
import ccbi.ip;
import ccbi.space;
import ccbi.utils;

// 0x494e4456: INDV
// Pointer functions
// -----------------

static this() {
	mixin (Code!("INDV"));

	fingerprints[INDV]['G'] =& getNum;
	fingerprints[INDV]['P'] =& putNum;
	fingerprints[INDV]['V'] =& getVec;
	fingerprints[INDV]['W'] =& putVec;
}

// get vector off of stack,,,,apply storage offset,,,,retrieve vector from
// funge-space,,,,apply storage offset,,,,retrieve vector from funge-space to
// stack,,,,,do not modify this last read vector...

// in all funcitons of INDV,,,,a vector is popped off the stack and the storage
// offset is applied,,,,that points to a vector in memory which is retrieved
// and the storage offset applied,,,,whatever data that points to is read as
// is....

// the final data read or written is not modified by the storage offset...
// only the 2 pointer vectors are... 

void getNum() {
	cellidx x, y;
	popVector(x, y);

	cellidx x2 = cast(cellidx)space[x+cast(cellidx)1, y],
	        y2 = cast(cellidx)space[x,                y];

	ip.stack.push(space[x2, y2]);
}

void putNum() {
	cellidx x, y;
	popVector(x, y);

	cellidx x2 = cast(cellidx)space[x+cast(cellidx)1, y],
	        y2 = cast(cellidx)space[x,                y];

	space[x2, y2] = ip.stack.pop;
}

void getVec() {
	cellidx x, y;
	popVector(x, y);

	cellidx x2 = cast(cellidx)space[x+cast(cellidx)1, y],
	        y2 = cast(cellidx)space[x,                y];

	ip.stack.push(
		space[x2+cast(cellidx)1, y2],
		space[x2,                y2]
	);
}

void putVec() {
	cellidx x, y;
	popVector(x, y);

	cellidx x2 = cast(cellidx)space[x+cast(cellidx)1, y],
	        y2 = cast(cellidx)space[x,                y];

	space[x2,                y2] = ip.stack.pop;
	space[x2+cast(cellidx)1, y2] = ip.stack.pop;
}
