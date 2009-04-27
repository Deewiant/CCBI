// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:14:58

module ccbi.fingerprints.rcfunge98.subr;

import ccbi.fingerprint;

// 0x53554252: SUBR
// Subroutine extension
// --------------------

mixin (Fingerprint!(
	"SUBR",

	"A", "absolute",
	"C", "call",
	"J", "jump",
	"O", "relative",
	"R", "ret"
));

template SUBR() {

void ctor() {
	if (!callStack.length)
		callStack.length = 8;
}

cell[] callStack;
size_t cs;

void push(cell n) {
	if (cs == callStack.length)
		callStack.length = callStack.length * 2;

	callStack[cs++] = n;
}

cell pop() { return callStack[--cs]; }

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
	popVector(cip.pos);

	while (n--)
		cip.stack.push(pop());
}

}
