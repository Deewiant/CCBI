// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 20:20:37

module ccbi.fingerprints.cats_eye.hrti; private:

import tango.time.Clock;
import tango.time.StopWatch;
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
	assert (resolution > 0, "Calculated timer granularity as negative!");
} body {
	if (resolution == 0) {
		// educated guess regarding granularity

		ip.timer.start;
		do resolution = ip.timer.microsec;
		while (resolution == 0);

		oneSecond = TimeSpan.fromSeconds(1).ticks,
		oneMicro  = TimeSpan.fromMicros (1).ticks;
	}
}

typeof(StopWatch.microsec()) resolution = 0;
typeof(TimeSpan.ticks()) oneSecond, oneMicro;

// Granularity
void granularity() { ip.stack.push(cast(cell)resolution); }

// Mark
void mark() { ip.timer.start; ip.timerMarked = true; }

// Timer
void timer() {
	if (ip.timerMarked)
		ip.stack.push(cast(cell)ip.timer.microsec);
	else
		reverse();
}

// Erase mark
void eraseMark() { ip.timerMarked = false; }

// Second
void second() { ip.stack.push(cast(cell)(Clock.now().ticks % oneSecond / oneMicro)); }
