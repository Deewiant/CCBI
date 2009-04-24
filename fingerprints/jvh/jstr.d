// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:16:29

module ccbi.fingerprints.jvh.jstr; private:

import ccbi.fingerprint;
import ccbi.instructions : reverse;
import ccbi.ip;
import ccbi.space;
import ccbi.utils;

// 0x4a535452: JSTR
// ----------------

static this() {
	mixin (Code!("JSTR"));

	fingerprints[JSTR]['P'] =& popN;
	fingerprints[JSTR]['G'] =& pushN;
}

void popN() {
	auto n = ip.stack.pop;
	cellidx x, y, dx, dy;

	popVector        ( x,  y);
	popVector!(false)(dx, dy);

	if (n < 0)
		return reverse();

	while (n--) {
		space[x, y] = ip.stack.pop;
		x += dx;
		y += dy;
	}
}

void pushN() {
	auto n = ip.stack.pop;
	cellidx x, y, dx, dy;

	popVector        ( x,  y);
	popVector!(false)(dx, dy);

	if (n < 0)
		return reverse();

	ip.stack.push(0);

	while (n--) {
		ip.stack.push(space[x, y]);
		x += dx;
		y += dy;
	}
}
