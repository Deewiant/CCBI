// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:07:48

module ccbi.fingerprints.cats_eye.refc;

import ccbi.fingerprint;

// 0x52454643: REFC
// Referenced Cells Extension
// --------------------------

mixin (Fingerprint!(
	"REFC",

	"D", "dereference",
	"R",   "reference"
));

template REFC() {

Coords[] references;

// Reference
void reference() {
	references ~= popVector();
	cip.stack.push(cast(cell)(references.length - 1));
}

// Dereference
void dereference() {
	auto idx = cip.stack.pop;
	if (idx >= references.length)
		return reverse();

	pushVector(references[idx]);
}

}
