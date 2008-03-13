// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:03:46

module ccbi.fingerprints.cats_eye.null_; private:

import ccbi.cell;
import ccbi.fingerprint;
import ccbi.instructions : reverse;

// 0x4e554c4c: NULL
// Funge-98 Null Fingerprint
// -------------------------

static this() {
	mixin (Code!("NULL"));
	for (cell c = 'A'; c <= 'Z'; ++c)
		fingerprints[NULL][c] =& reverse;
}
