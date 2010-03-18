// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2007-01-20 20:20:37

module ccbi.fingerprints.cats_eye.hrti;

import ccbi.fingerprint;

mixin (Fingerprint!(
	"HRTI",
	"High-Resolution Timer Interface",

	"G", "granularity",
	"M", "mark",
	"T", "timer",
	"E", "eraseMark",
	"S", "second"
));

template HRTI() {

import tango.time.Clock;
import tango.time.StopWatch;

void ctor()
out {
	assert (resolution >= 0, "Calculated timer granularity as negative!");
} body {
	if (resolution == -1) {
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
