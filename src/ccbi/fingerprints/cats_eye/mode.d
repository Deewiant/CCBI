// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:10:55

module ccbi.fingerprints.cats_eye.mode;

import ccbi.fingerprint;

mixin (Fingerprint!(
	"MODE",
	"Funge-98 Standard Modes

      The stack stack is unaffected by both invertmode and queuemode.\n",

	"H", "toggleHovermode",
	"I", "toggleInvertmode",
	"Q", "toggleQueuemode",
	"S", "toggleSwitchmode"
));

template MODE() {

void ctor() {
	auto deque = cip.stack.isDeque;

	if (cip.stackStack) {
		foreach (inout s; *cip.stackStack) {
			assert (deque == s.isDeque);
			if (!deque) {
				s.isDeque = true;
				s.deque = Deque(&dequeStats, s.stack);
			}
		}
	} else if (!deque) {
		cip.stack.isDeque = true;
		cip.stack.deque = Deque(&dequeStats, cip.stack.stack);
	}
}

void dtor() {
	// Leaving modes on after unloading is bad practice IMHO, but it could
	// happen...
	if (cip.stack.deque.mode & (INVERT_MODE | QUEUE_MODE))
		return;

	if (cip.stackStack) {
		foreach (inout s; *cip.stackStack) {
			assert (s.isDeque);
			s.isDeque = false;
			s.stack = Stack!(cell)(&stackStats, s.deque);
		}
	} else {
		assert (cip.stack.isDeque);
		cip.stack.isDeque = false;
		cip.stack.stack = Stack!(cell)(&stackStats, cip.stack.deque);
	}
}

// Toggle Hovermode, Toggle Switchmode, Toggle Invertmode, Toggle Queuemode
void toggleHovermode () { cip.mode ^= IP.HOVER;  }
void toggleSwitchmode() { cip.mode ^= IP.SWITCH; }
void toggleInvertmode() { assert (cip.stack.isDeque); cip.stack.deque.mode ^= INVERT_MODE; }
void toggleQueuemode () { assert (cip.stack.isDeque); cip.stack.deque.mode ^= QUEUE_MODE;  }

}
