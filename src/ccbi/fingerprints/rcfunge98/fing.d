// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2010-03-12 18:33:42

module ccbi.fingerprints.rcfunge98.fing;

import ccbi.fingerprint;

mixin (Fingerprint!(
	"FING",
	"Operate on single fingerprint semantics",

	"X", "swap",
	"Y", "pop",
	"Z", "copy"
));

template FING() {

private bool popIdx(out cell c) {
	c = cip.stack.pop;
	if (c >= 'A')
		c -= 'A';
	return isSemantics(c + 'A');
}

void swap() {
	cell a, b;

	if (!popIdx(a) || !popIdx(b))
		return reverse;

	auto asems = cip.requireSems(a, &semanticStats);
	auto bsems = cip.requireSems(b, &semanticStats);

	auto asem = asems.empty ? Semantics(HexCode!("NULL"), a + 'A') : asems.pop;
	auto bsem = bsems.empty ? Semantics(HexCode!("NULL"), b + 'A') : bsems.pop;

	asems.push(bsem);
	bsems.push(asem);
}

void pop() {
	cell i;
	if (!popIdx(i))
		return reverse;

	if (cip.semantics[i] && !cip.semantics[i].empty)
		cip.semantics[i].pop(1);
}

void copy() {
	cell src, dst;
	if (!popIdx(dst) || !popIdx(src))
		return reverse;

	cip.requireSems(dst, &semanticStats).push(
		  cip.semantics[src] && !cip.semantics[src].empty
		? cip.semantics[src].top
		: Semantics(HexCode!("NULL"), src + 'A'));
}

}
