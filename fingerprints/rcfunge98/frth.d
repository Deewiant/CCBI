// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:14:19

module ccbi.fingerprints.rcfunge98.frth; private:

import ccbi.fingerprint;
import ccbi.ip;

// 0x46525448: FRTH
// Some common forth commands
// --------------------------

static this() {
	mixin (Code!("FRTH"));

	fingerprints[FRTH]['D'] =& stackSize;
	fingerprints[FRTH]['L'] =& forthRoll;
	fingerprints[FRTH]['O'] =& forthOver;
	fingerprints[FRTH]['P'] =& forthPick;
	fingerprints[FRTH]['R'] =& forthRot;
}

void stackSize() { ip.stack.push(cast(cell)ip.stack.size); }

void forthOver() {
	with (ip.stack) {
		auto b = pop, a = pop;

		push(a, b, a);
	}
}

void forthRot() {
	with (ip.stack) {
		auto c = pop, b = pop, a = pop;

		push(b, c, a);
	}
}

// copy u-th from top to top
void forthPick() {
	with (ip.stack) {
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
	with (ip.stack) {
		auto u = pop,
		     s = size;

		if (u >= s)
			push(0);
		else {
			auto elems = elementsBottomToTop;
			auto xu = elems[s - (u+1)];

			pop(u+1);

			push(elems[s-u..$]);
			push(xu);
		}
	}
}
