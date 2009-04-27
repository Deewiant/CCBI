// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:14:36

module ccbi.fingerprints.rcfunge98.imap;

import ccbi.fingerprint;

// 0x494d4150: IMAP
// Instruction remap extension
// ---------------------------

mixin (Fingerprint!(
	"IMAP",

	"C", "unmapAll",
	"M", "remap",
	"O", "unmap"
));

template IMAP() {

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