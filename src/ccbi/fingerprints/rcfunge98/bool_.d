// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2010-04-10 20:17:11

module ccbi.fingerprints.rcfunge98.bool_;

import ccbi.fingerprint;

mixin (Fingerprint!(
	"BOOL",
	"Logic functions",

	"A", "and",
	"N", "not",
	"O", "or",
	"X", "xor"));

template BOOL() {

void and() { with (*cip.stack) push(pop & pop); }
void  or() { with (*cip.stack) push(pop | pop); }
void xor() { with (*cip.stack) push(pop ^ pop); }
void not() { with (*cip.stack) push(~pop); }

}
