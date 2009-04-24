// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 20:20:37

module ccbi.fingerprints.cats_eye.hrti;

import ccbi.fingerprint;

// 0x48525449: HRTI
// High-Resolution Timer Interface
// -------------------------------

mixin (Fingerprint!(
	"HRTI",

	"G", "granularity",
	"M", "mark",
	"T", "timer",
	"E", "eraseMark",
	"S", "second"
));

template HRTI() {

import tango.time.StopWatch;

void ctor()
out {
	assert (resolution > 0, "Calculated timer granularity as negative!");
} body {
	if (resolution < 0) {
		cip.timer.start;
		resolution = cip.timer.microsec;
	}
}

typeof(StopWatch.microsec()) resolution = -1;

// Granularity
void granularity() { cip.stack.push(cast(cell)resolution); }

// Mark
void mark() { cip.timer.start; cip.timerMarked = true; }

// Timer
void timer() {
	if (cip.timerMarked)
		cip.stack.push(cast(cell)cip.timer.microsec);
	else
		reverse();
}

// Erase mark
void eraseMark() { cip.timerMarked = false; }

// Second
void second() {
	cip.stack.push(cast(cell)(
		Clock.now().ticks % TimeSpan.fromSeconds(1).ticks
		/ TimeSpan.fromMicros(1).ticks));
}

}
