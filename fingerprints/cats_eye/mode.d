// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:10:55

module ccbi.fingerprints.cats_eye.mode; private:

import ccbi.container;
import ccbi.fingerprint;
import ccbi.instructions;
import ccbi.ip;
import ccbi.space;

// 0x4d4f4445: MODE
// Funge-98 Standard Modes
// -----------------------

static this() {
	mixin (Code!("MODE"));

	fingerprints[MODE]['H'] =& toggleHovermode;
	fingerprints[MODE]['I'] =& toggleInvertmode;
	fingerprints[MODE]['Q'] =& toggleQueuemode;
	fingerprints[MODE]['S'] =& toggleSwitchmode;

	fingerprintConstructors[MODE] =& ctor;
	fingerprintDestructors [MODE] =& dtor;
}

void ctor() {
	foreach (inout i; ips) {
		foreach (inout s; i.stackStack)
			s = new Deque(s);
		i.stack = i.stackStack.top;
	}
}

void dtor() {
	// leaving modes on after unloading is bad practice IMHO, but it could happen...
	foreach (i; ips)
	if (i.stack.mode & (INVERT_MODE | QUEUE_MODE))
		return;

	foreach (inout i; ips) {
		foreach (inout s; i.stackStack)
			s = new Stack!(cell)(s);
		i.stack = i.stackStack.top;
	}
}

// Toggle Hovermode, Toggle Switchmode, Toggle Invertmode, Toggle Queuemode
void toggleHovermode () { ip.mode ^= IP.HOVER;  }
void toggleSwitchmode() { ip.mode ^= IP.SWITCH; }
void toggleInvertmode() { auto q = cast(Deque)(ip.stack); assert (q !is null); q.mode ^= INVERT_MODE; }
void toggleQueuemode () { auto q = cast(Deque)(ip.stack); assert (q !is null); q.mode ^= QUEUE_MODE;  }
