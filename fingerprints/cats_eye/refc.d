// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:07:48

module ccbi.fingerprints.cats_eye.refc; private:

import ccbi.fingerprint;
import ccbi.instructions : reverse;
import ccbi.ip;
import ccbi.utils;

// 0x52454643: REFC
// Referenced Cells Extension
// --------------------------

static this() {
	mixin (Code!("REFC"));

	fingerprints[REFC]['D'] =& dereference;
	fingerprints[REFC]['R'] =&   reference;
}

cellidx[2][] references;

// Reference
void reference() {
	cellidx x, y;
	popVector!(false)(x, y);
	references ~= [x, y];
	ip.stack.push(cast(cell)(references.length - 1));
}

// Dereference
void dereference() {
	auto idx = ip.stack.pop;
	if (idx >= references.length)
		return reverse();

	auto vec = references[idx];
	pushVector!(false)(vec[0], vec[1]);
}
