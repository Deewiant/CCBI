// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:10:55

module ccbi.fingerprints.cats_eye.mode;

import ccbi.fingerprint;

// 0x4d4f4445: MODE
// Funge-98 Standard Modes
// -----------------------

mixin (Fingerprint!(
	"MODE",

	"H", "toggleHovermode",
	"I", "toggleInvertmode",
	"Q", "toggleQueuemode",
	"S", "toggleSwitchmode"
));

template MODE() {

void ctor() {
	if (cip.stackStack) {
		foreach (inout s; cip.stackStack)
			if (auto st = cast(Stack!(cell))s)
				s = new Deque(&dequeStats, st);
		cip.stack = cip.stackStack.top;

	} else if (auto st = cast(Stack!(cell))cip.stack)
		cip.stack = new Deque(&dequeStats, st);
}

void dtor() {
	// Leaving modes on after unloading is bad practice IMHO, but it could
	// happen...
	if (cip.stack.mode & (INVERT_MODE | QUEUE_MODE))
		return;

	if (cip.stackStack) {
		foreach (inout s; cip.stackStack) {
			assert (cast(Deque)s);
			s = new Stack!(cell)(&stackStats, cast(Deque)s);
		}
		cip.stack = cip.stackStack.top;
	} else {
		assert (cast(Deque)cip.stack);
		cip.stack = new Stack!(cell)(&stackStats, cast(Deque)cip.stack);
	}
}

// Toggle Hovermode, Toggle Switchmode, Toggle Invertmode, Toggle Queuemode
void toggleHovermode () { cip.mode ^= IP.HOVER;  }
void toggleSwitchmode() { cip.mode ^= IP.SWITCH; }
void toggleInvertmode() { auto q = cast(Deque)(cip.stack); assert (q !is null); q.mode ^= INVERT_MODE; }
void toggleQueuemode () { auto q = cast(Deque)(cip.stack); assert (q !is null); q.mode ^= QUEUE_MODE;  }

}
