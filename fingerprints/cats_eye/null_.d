// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:03:46

module ccbi.fingerprints.cats_eye.null_;

import ccbi.fingerprint;
import ccbi.templateutils;

// 0x4e554c4c: NULL
// Funge-98 Null Fingerprint
// -------------------------

// WORKAROUND: http://d.puremagic.com/issues/show_bug.cgi?id=1059
// mixin (Fingerprint!("NULL", Range!('A','Z'), "reverse"));
mixin (Fingerprint!("NULL", "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "reverse"));

template NULL() { alias Std.reverse reverse; }
