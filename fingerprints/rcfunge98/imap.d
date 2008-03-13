// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:14:36

module ccbi.fingerprints.rcfunge98.imap; private:

import ccbi.fingerprint;
import ccbi.instructions : reverse;
import ccbi.ip;

// 0x494d4150: IMAP
// Instruction remap extension
// ---------------------------

static this() {
	mixin (Code!("IMAP"));

	fingerprints[IMAP]['C'] =& unmapAll;
	fingerprints[IMAP]['M'] =& remap;
	fingerprints[IMAP]['O'] =& unmap;
}

void remap() {
	auto old = ip.stack.pop;
	if (old >= 0 && old < ip.mapping.length)
		ip.mapping[old] = ip.stack.pop;
	else {
		ip.stack.pop(1);
		reverse();
	}
}

void unmap() {
	auto i = ip.stack.pop;
	if (i >= 0 && i < ip.mapping.length)
		ip.mapping[i] = i;
	else
		reverse();
}

void unmapAll() {
	foreach (j, inout i; ip.mapping)
		i = cast(cell)j;
}
