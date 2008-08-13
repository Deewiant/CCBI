// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:05:10

module ccbi.fingerprints.cats_eye.orth; private:

import tango.io.Stdout : Stdout;

import ccbi.fingerprint;
import ccbi.instructions : trampoline;
import ccbi.ip;
import ccbi.space;
import ccbi.utils;

// 0x4f525448: ORTH
// Orthogonal Easement Library
// ---------------------------

static this() {
	mixin (Code!("ORTH"));

	fingerprints[ORTH]['A'] =& bitAnd;
	fingerprints[ORTH]['E'] =& bitXor;
	fingerprints[ORTH]['G'] =& orthoGet;
	fingerprints[ORTH]['O'] =& bitOr;
	fingerprints[ORTH]['P'] =& orthoPut;
	fingerprints[ORTH]['S'] =& outputString;
	fingerprints[ORTH]['V'] =& changeDx;
	fingerprints[ORTH]['W'] =& changeDy;
	fingerprints[ORTH]['X'] =& changeX;
	fingerprints[ORTH]['Y'] =& changeY;
	fingerprints[ORTH]['Z'] =& rampIfZero;
}

// bitwise AND, bitwise OR, bitwise EXOR
void bitAnd() { with (ip.stack) push(pop & pop); }
void bitOr () { with (ip.stack) push(pop | pop); }
void bitXor() { with (ip.stack) push(pop ^ pop); }

// ortho get
void orthoGet() {
	cellidx x, y;

	popVector!(false)(y, x);

	ip.stack.push(space[x, y]);
}

// ortho put
void orthoPut() {
	cellidx x, y;

	popVector!(false)(y, x);

	cell c = ip.stack.pop;

	if (y > space.endY)
		space.endY = y;
	else if (y < space.begY)
		space.begY = y;
	if (x > space.endX)
		space.endX = x;
	else if (x < space.begX)
		space.begX = x;

	space[x, y] = c;
}

// output string
void outputString() { Stdout(popString()); }

// change dx
void changeDx() { ip.dx = cast(cellidx)ip.stack.pop; }

// change dy
void changeDy() { ip.dy = cast(cellidx)ip.stack.pop; }

// change x
void changeX()  { ip. x = cast(cellidx)ip.stack.pop; }

// change x
void changeY()  { ip. y = cast(cellidx)ip.stack.pop; }

// ramp if zero
void rampIfZero() {
	if (!ip.stack.pop)
		trampoline();
}
