// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:16:29

module ccbi.fingerprints.jvh.jstr;

import ccbi.fingerprint;

// 0x4a535452: JSTR
// ----------------

mixin (Fingerprint!(
	"JSTR",

	"P", "popN",
	"G", "pushN"
));

template JSTR() {

void popN() {
	auto n = cip.stack.pop;

	Coords c = popOffsetVector();
	Coords d = popVector();

	if (n < 0)
		return reverse();

	while (n--) {
		state.space[c] = cip.stack.pop;
		c += d;
	}
}

void pushN() {
	auto n = cip.stack.pop;

	Coords c = popOffsetVector();
	Coords d = popVector();

	if (n < 0)
		return reverse();

	cip.stack.push(0);

	auto p = cip.stack.reserve(n);
	while (n--) {
		*p++ = state.space[c];
		c += d;
	}
}

}
