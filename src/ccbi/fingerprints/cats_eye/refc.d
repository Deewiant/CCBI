// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:07:48

module ccbi.fingerprints.cats_eye.refc;

import ccbi.fingerprint;

mixin (Fingerprint!(
	"REFC",
	"Referenced Cells Extension

      Since there is no way of forgetting about a referenced vector, prolific
      use of the 'R' instruction can and will lead to a shortage of memory.\n",

	"D", "dereference",
	"R",   "reference"
));

template REFC() {

// Reference
void reference() {
	state.references ~= popVector();
	cip.stack.push(cast(cell)(state.references.length - 1));
}

// Dereference
void dereference() {
	auto idx = cip.stack.pop;
	if (idx >= state.references.length)
		return reverse();

	pushVector(state.references[idx]);
}

}
