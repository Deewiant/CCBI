// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:14:58

module ccbi.fingerprints.rcfunge98.subr; private:

import ccbi.fingerprint;
import ccbi.instructions : goEast;
import ccbi.ip;
import ccbi.utils;

// 0x53554252: SUBR
// Subroutine extension
// --------------------

static this() {
	mixin (Code!("SUBR"));

	fingerprints[SUBR]['C'] =& call;
	fingerprints[SUBR]['J'] =& jump;
	fingerprints[SUBR]['R'] =& ret;

	fingerprintConstructors[SUBR] =& cons;
}

void cons() {
	if (!callStack.length)
		callStack.length = 8;
}

cell[] callStack;
size_t cs;

private void push(cell n) {
	if (cs == callStack.length)
		callStack.length = callStack.length * 2;

	callStack[cs++] = n;
}

private cell pop() {
	return callStack[--cs];
}

void call() {
	auto n = cast(size_t)ip.stack.pop;
	cellidx x, y;
	popVector(x, y);

	for (size_t i = 0; i < n; ++i)
		push(ip.stack.pop());

	pushVector        (ip. x, ip. y);
	pushVector!(false)(ip.dx, ip.dy);

	while (n--)
		ip.stack.push(pop());

	ip.x = x;
	ip.y = y;
	goEast();
	needMove = false;
}

void jump() {
	popVector(ip.x, ip.y);
	goEast();
	needMove = false;
}

void ret() {
	auto n = cast(size_t)ip.stack.pop;

	for (size_t i = 0; i < n; ++i)
		push(ip.stack.pop());

	popVector!(false)(ip.dx, ip.dy);
	popVector        (ip. x, ip. y);

	while (n--)
		ip.stack.push(pop());
}
