// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:05:10

module ccbi.fingerprints.cats_eye.orth;

import ccbi.fingerprint;

mixin (Fingerprint!(
	"ORTH",
	"Orthogonal Easement Library

      'G' and 'P' do not apply the storage offset.\n",

	"A", "bitAnd",
	"E", "bitXor",
	"G", "orthoGet",
	"O", "bitOr",
	"P", "orthoPut",
	"S", "outputString",
	"V", "changeDx",
	"W", "changeDy",
	"X", "changeX",
	"Y", "changeY",
	"Z", "rampIfZero"
));

template ORTH() {

// bitwise AND, bitwise OR, bitwise EXOR
void bitAnd() { with (*cip.stack) push(pop & pop); }
void bitOr () { with (*cip.stack) push(pop | pop); }
void bitXor() { with (*cip.stack) push(pop ^ pop); }

// ortho get
void orthoGet() {
	with (*cip.stack) {
		Coords c;
		with (c) {
			                     x = pop;
			static if (dim >= 2) y = pop;
			static if (dim >= 3) z = pop;
		}
		push(state.space[c]);
	}
}

// ortho put
void orthoPut() {
	with (*cip.stack) {
		Coords c;
		with (c) {
			                     x = pop;
			static if (dim >= 2) y = pop;
			static if (dim >= 3) z = pop;
		}
		state.space[c] = pop;
	}
}

// output string
void outputString() {
	static if (GOT_TRDS)
		if (state.tick < ioAfter)
			return popString();

	Sout(popString());
}

// change dx
void changeDx() { cip.delta.x = cip.stack.pop; }

// change dy
void changeDy() { static if (dim >= 2) cip.delta.y = cip.stack.pop; else reverse; }

// change x
void changeX() { auto c = cip.pos; c.x = cip.stack.pop; cip.pos = c; }

// change x
void changeY() { static if (dim >= 2) { auto c = cip.pos; c.y = cip.stack.pop; cip.pos = c; } else reverse; }

// ramp if zero
void rampIfZero() {
	if (!cip.stack.pop)
		trampoline();
}

}
