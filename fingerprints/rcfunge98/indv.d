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
		space[x2,                y2],
		space[x2+cast(cellidx)1, y2]
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
