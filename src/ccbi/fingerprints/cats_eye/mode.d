// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

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

void ipCtor() {
	auto isDeque = cip.stack.isDeque;

	if (cip.stackStack) {
		foreach (inout s; *cip.stackStack) {
			assert (isDeque == s.isDeque);
			if (!isDeque) {
				s.isDeque = true;
				auto deque = Deque(&dequeStats, s.stack);
				s.stack.free();
				s.deque = deque;
			}
		}
	} else if (!isDeque) {
		cip.stack.isDeque = true;
		auto deque = Deque(&dequeStats, cip.stack.stack);
		cip.stack.stack.free();
		cip.stack.deque = deque;
	}
}

void ipDtor() {
	// Leaving modes on after unloading is bad practice IMHO, but it could
	// happen...
	if (cip.stack.deque.mode & (INVERT_MODE | QUEUE_MODE))
		return;

	if (cip.stackStack) {
		foreach (inout s; *cip.stackStack) {
			assert (s.isDeque);
			s.isDeque = false;
			auto stack = Stack!(cell)(&stackStats, s.deque);
			s.deque.free();
			s.stack = stack;
		}
	} else {
		assert (cip.stack.isDeque);
		cip.stack.isDeque = false;
		auto stack = Stack!(cell)(&stackStats, cip.stack.deque);
		cip.stack.deque.free();
		cip.stack.stack = stack;
	}
}

// Toggle Hovermode, Toggle Switchmode, Toggle Invertmode, Toggle Queuemode
void toggleHovermode () { cip.mode ^= IP.HOVER;  }
void toggleSwitchmode() { cip.mode ^= IP.SWITCH; }
void toggleInvertmode() { assert (cip.stack.isDeque); cip.stack.deque.mode ^= INVERT_MODE; }
void toggleQueuemode () { assert (cip.stack.isDeque); cip.stack.deque.mode ^= QUEUE_MODE;  }

}
