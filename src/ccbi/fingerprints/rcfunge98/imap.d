// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2007-01-20 21:14:36

module ccbi.fingerprints.rcfunge98.imap;

import ccbi.fingerprint;

mixin (Fingerprint!(
	"IMAP",
	"Instruction remap extension",

	"C", "unmapAll",
	"M", "remap",
	"O", "unmap"
));

template IMAP() {

void ctor() {
	// Support mapping 0 through 255
	cip.mapping = new typeof(cip.mapping)(256);
	foreach (j, inout i; cip.mapping)
		i = cast(cell)j;
}
void dtor() {
	foreach (j, i; cip.mapping)
		if (i != j)
			return;

	delete cip.mapping;
}

void remap() {
	auto old = cip.stack.pop;
	if (old >= 0 && old < cip.mapping.length)
		cip.mapping[old] = cip.stack.pop;
	else {
		cip.stack.pop(1);
		reverse();
	}
}

void unmap() {
	auto i = cip.stack.pop;
	if (i >= 0 && i < cip.mapping.length)
		cip.mapping[i] = i;
	else
		reverse();
}

void unmapAll() {
	foreach (j, inout i; cip.mapping)
		i = cast(cell)j;
}

}
