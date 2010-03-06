// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:14:19

module ccbi.fingerprints.rcfunge98.frth;

import ccbi.fingerprint;

// 0x46525448: FRTH
// Some common forth commands
// --------------------------

mixin (Fingerprint!(
	"FRTH",

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
			push(elementsBottomToTop[s - (u+1)]);
	}
}

// move u-th from top to top
void forthRoll() {
	with (*cip.stack) {
		auto u = pop,
		     s = size;

		// TODO: -ROLL for negative
		if (u >= s)
			push(0);
		else {
			auto elems = elementsBottomToTop;
			auto xu = elems[s - (u+1)];

			pop(u+1);

			foreach (c; elems[s-u..$])
				push(c);
			push(xu);
		}
	}
}

}
