// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 20:20:37

module ccbi.fingerprints.cats_eye.hrti; private:

import tango.time.Clock;
import tango.io.Stdout;

import ccbi.fingerprint;
import ccbi.instructions : reverse;
import ccbi.ip;

// 0x48525449: HRTI
// High-Resolution Timer Interface
// -------------------------------

static this() {
	mixin (Code!("HRTI"));

	fingerprints[HRTI]['G'] =& granularity;
	fingerprints[HRTI]['M'] =& mark;
	fingerprints[HRTI]['T'] =& timer;
	fingerprints[HRTI]['E'] =& eraseMark;
	fingerprints[HRTI]['S'] =& second;

	fingerprintConstructors[HRTI] =& ctor;
}

void ctor()
out {
	assert (resolution > TimeSpan.zero, "Calculated timer granularity as negative!");
} body {
	if (resolution == TimeSpan.zero) {
		// educated guess regarding granularity
		auto time = Clock.now();

		do resolution = Clock.now() - time;
		while (resolution == TimeSpan.zero);

		oneSecond  = TimeSpan.seconds(1).ticks,
		oneMicro   = TimeSpan.micros (1).ticks;
	}
}

TimeSpan	resolution = TimeSpan.zero;
typeof(TimeSpan.ticks()) oneSecond, oneMicro;

// Granularity
void granularity() { ip.stack.push(cast(cell)(resolution.micros)); }

// Mark
void mark() { ip.timeMark = Clock.now(); }

// Timer
void timer() {
	if (ip.timeMark == Time.min)
		reverse();
	else
		ip.stack.push(cast(cell)((Clock.now() - ip.timeMark).micros));
}

// Erase mark
void eraseMark() { ip.timeMark = typeof(ip.timeMark).min; }

// Second
void second() { ip.stack.push(cast(cell)(Clock.now().ticks % oneSecond / oneMicro)); }
