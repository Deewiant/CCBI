// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2010-05-27 12:01:26

module ccbi.fingerprints.rcfunge98.trgr;

import ccbi.fingerprint;

mixin (Fingerprint!(
	"TRGR",
	"Triggers",

	// See WORKAROUND in SingleIns.Ins for why it's not just "trigger(c)"
	"ABCDEFGHIJKLMNOQPRSTUVWXY", "return TRGR.trigger(c);",
	"Z", "setTriggerTable"));

template TRGR() {

bool triggerTableSet = false;
Coords triggerTable  = void;

Request trigger(cell c) {
	if (!triggerTableSet)
		return reverse;

	auto offset = c - 'A';

	static if (dim < 2)
		if (offset != 0)
			return reverse;

	auto nip = forkCip();

	nip.pos = triggerTable;

	nip.pos.x -= 1; // Since it'll get moved

	static if (dim >= 2)
		nip.pos.y += offset;

	nip.delta = InitCoords!(1);

	cip.stack.push(nip.id);
	nip.stack.push(cip.id);

	return forkDone(nip);
}

void setTriggerTable() {
	triggerTable = popOffsetVector();
	triggerTableSet = true;
}

}
