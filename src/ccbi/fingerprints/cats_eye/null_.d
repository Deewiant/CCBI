// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2007-01-20 21:03:46

module ccbi.fingerprints.cats_eye.null_;

import ccbi.fingerprint;
import ccbi.templateutils;

// WORKAROUND: http://d.puremagic.com/issues/show_bug.cgi?id=1059
// Range!('A','Z')
mixin (Fingerprint!(
	"NULL", "Funge-98 Null Fingerprint",
	"ABCDEFGHIJKLMNOPQRSTUVWXYZ", "reverse"));
