// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:14:19

module ccbi.fingerprints.rcfunge98.frth;

import ccbi.fingerprint;

mixin (Fingerprint!(
	"FRTH",
	"Some common forth [sic] commands",

	"D", "stackSize",
	"L", "forthRoll",
	"O", "forthOver",
	"P", "forthPick",
	"R", "forthRot"
));

template FRTH() {

void stackSize() { with (*cip.stack) push(cast(cell)size); }

void forthOver() {
	with (*cip.stack) {
		auto b = pop, a = pop;

		push(a, b, a);
	}
}

void forthRot() {
	with (*cip.stack) {
		auto c = pop, b = pop, a = pop;

		push(b, c, a);
	}
}

// copy u-th from top to top
void forthPick() {
	with (*cip.stack) {
		auto u = pop,
		     s = size;

		if (u >= s)
			push(0);
		else
			push(at(s - (u+1)));
	}
}

// move u-th from top to top
void forthRoll() {
	with (*cip.stack) {
		auto u = pop + 1, // zero-based from top
		     s = size;

		// TODO: -ROLL for negative
		if (u > s)
			push(0);
		else {
			auto xu = at(s - u);

			// These null function arguments are valid because we know that we
			// can't underflow
			if (cip.stack.mode & QUEUE_MODE) {
				// Move the bottom u elements right by one
				mapFirstN(u, (cell[] a) {
					memmove(a.ptr + 1, a.ptr, (a.length - 1) * cell.sizeof);
				}, null);
			} else {
				// Move the top u elements left by one
				mapFirstN(u, (cell[] a) {
					memmove(a.ptr, a.ptr + 1, (a.length - 1) * cell.sizeof);
				}, null);
			}
			// Remove leftover nonsense on stack
			pop(1);

			push(xu);
		}
	}
}

}
