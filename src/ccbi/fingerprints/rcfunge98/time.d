// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:15:14

module ccbi.fingerprints.rcfunge98.time;

import ccbi.fingerprint;

// 0x54494d45: TIME
// Time and Date functions
// -----------------------

mixin (Fingerprint!(
	"TIME",

	"D", "day",
	"F", "dayOfYear",
	"G", "useGMT",
	"H", "hour",
	"L", "useLocal",
	"M", "minute",
	"O", "month",
	"S", "second",
	"W", "dayOfWeek",
	"Y", "year"
));

template TIME() {

import tango.time.Clock;
import tango.time.WallClock;
import tango.time.chrono.Gregorian;

void useGMT()   { state.utc = true;  }
void useLocal() { state.utc = false; }

template TimeFunc(char[] internal_f, char[] f, char[] offset = "0") {
	const TimeFunc =
		"void " ~ internal_f ~ "() {"
		"	cip.stack.push(cast(cell)("
		"		(state.utc ? Clock.now : WallClock.now).time." ~f~ " + " ~offset~ "));"
		"}";
}
template DateFunc(char[] internal_f, char[] f, char[] offset = "0") {
	const DateFunc =
		"void " ~ internal_f ~ "() {"
		"	cip.stack.push(cast(cell)(Gregorian.generic."
		"		" ~f~ "(state.utc ? Clock.now : WallClock.now) + " ~offset~ "));"
		"}";
}

mixin (DateFunc!("day",       "getDayOfMonth"));
mixin (DateFunc!("dayOfYear", "getDayOfYear", "-1"));
mixin (TimeFunc!("hour",      "hours"));
mixin (TimeFunc!("minute",    "minutes"));
mixin (DateFunc!("month",     "getMonth"));
mixin (TimeFunc!("second",    "seconds"));
mixin (DateFunc!("dayOfWeek", "getDayOfWeek", "1"));
mixin (DateFunc!("year",      "getYear"));

}
