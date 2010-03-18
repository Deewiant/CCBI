// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2007-01-20 21:14:58

module ccbi.fingerprints.rcfunge98.subr;

import ccbi.fingerprint;

mixin (Fingerprint!(
	"SUBR",
	"Subroutine extension",

	"A", "absolute",
	"C", "call",
	"J", "jump",
	"O", "relative",
	"R", "ret"
));

// TODO switch to a Stack, needs stats
template SUBR() {

void ctor() {
	if (!state.callStack.length)
		state.callStack.length = 8;
}

void push(cell n) {
	if (state.cs == state.callStack.length)
		state.callStack.length = state.callStack.length * 2;

	state.callStack[state.cs++] = n;
}

cell pop() { return state.callStack[--state.cs]; }

void absolute() { cip.mode &= ~IP.SUBR_RELATIVE; }
void relative() { cip.mode |=  IP.SUBR_RELATIVE; }

Coords subrPopVector() {
	if (cip.mode & IP.SUBR_RELATIVE)
		return popOffsetVector;
	else
		return popVector;
}

Request call() {
	auto n = cast(size_t)cip.stack.pop;
	Coords c = subrPopVector();

	for (size_t i = 0; i < n; ++i)
		push(cip.stack.pop());

	pushVector(cip.pos);
	pushVector(cip.delta);

	while (n--)
		cip.stack.push(pop());

	cip.pos = c;
	reallyGoEast();
	return Request.NONE;
}

Request jump() {
	cip.pos = subrPopVector();
	reallyGoEast();
	return Request.NONE;
}

void ret() {
	auto n = cast(size_t)cip.stack.pop;

	for (size_t i = 0; i < n; ++i)
		push(cip.stack.pop());

	popVector(cip.delta);

	Coords c;
	popVector(c);
	cip.pos = c;

	while (n--)
		cip.stack.push(pop());
}

}
