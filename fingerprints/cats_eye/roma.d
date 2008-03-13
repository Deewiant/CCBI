// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:08:15

module ccbi.fingerprints.cats_eye.roma; private:

import ccbi.fingerprint;
import ccbi.instructions : PushNumber, PushNumberFunc;
import ccbi.ip;

// 0x524f4d41: ROMA
// Funge-98 Roman Numerals
// -----------------------

static this() {
	mixin (Code!("ROMA"));

	fingerprints[ROMA]['I'] =& mixin (PushNumber!(1));
	fingerprints[ROMA]['V'] =& mixin (PushNumber!(5));
	fingerprints[ROMA]['X'] =& mixin (PushNumber!(10));
	fingerprints[ROMA]['L'] =& mixin (PushNumber!(50));
	fingerprints[ROMA]['C'] =& mixin (PushNumber!(100));
	fingerprints[ROMA]['D'] =& mixin (PushNumber!(500));
	fingerprints[ROMA]['M'] =& mixin (PushNumber!(1000));
}

mixin (PushNumberFunc!(1));
mixin (PushNumberFunc!(5));
mixin (PushNumberFunc!(10));
mixin (PushNumberFunc!(50));
mixin (PushNumberFunc!(100));
mixin (PushNumberFunc!(500));
mixin (PushNumberFunc!(1000));
