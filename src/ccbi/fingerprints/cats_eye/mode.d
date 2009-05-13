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
	foreach (inout ip; state.ips) {
		foreach (inout s; ip.stackStack) {
			auto st = cast(Stack!(cell))s;
			if (st)
				s = new Deque(&dequeStats, st);
		}
		ip.stack = ip.stackStack.top;
	}
}

void dtor() {
	// Leaving modes on after unloading is bad practice IMHO, but it could
	// happen...
	foreach (ip; state.ips)
	if (ip.stack.mode & (INVERT_MODE | QUEUE_MODE))
		return;

	foreach (inout ip; state.ips) {
		foreach (inout s; ip.stackStack) {
			assert (cast(Deque)s);
			s = new Stack!(cell)(&stackStats, cast(Deque)s);
		}
		ip.stack = ip.stackStack.top;
	}
}

// Toggle Hovermode, Toggle Switchmode, Toggle Invertmode, Toggle Queuemode
void toggleHovermode () { cip.mode ^= IP.HOVER;  }
void toggleSwitchmode() { cip.mode ^= IP.SWITCH; }
void toggleInvertmode() { auto q = cast(Deque)(cip.stack); assert (q !is null); q.mode ^= INVERT_MODE; }
void toggleQueuemode () { auto q = cast(Deque)(cip.stack); assert (q !is null); q.mode ^= QUEUE_MODE;  }

}
