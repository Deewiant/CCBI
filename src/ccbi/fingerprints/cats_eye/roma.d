// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:08:15

module ccbi.fingerprints.cats_eye.roma;

import ccbi.fingerprint;
import ccbi.instructions.utils;

mixin (Fingerprint!(
	"ROMA",
	"Funge-98 Roman Numerals",
	"I", PushNumber!(1),
	"V", PushNumber!(5),
	"X", PushNumber!(10),
	"L", PushNumber!(50),
	"C", PushNumber!(100),
	"D", PushNumber!(500),
	"M", PushNumber!(1000)
));
