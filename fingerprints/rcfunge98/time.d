// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:15:14

module ccbi.fingerprints.rcfunge98.time; private:

import tango.time.Clock;
import tango.time.WallClock;
import tango.time.chrono.Gregorian;

import ccbi.fingerprint;
import ccbi.ip;

// 0x54494d45: TIME
// Time and Date functions
// -----------------------

static this() {
	mixin (Code!("TIME"));

	fingerprints[TIME]['D'] =& day;
	fingerprints[TIME]['F'] =& dayOfYear;
	fingerprints[TIME]['G'] =& useGMT;
	fingerprints[TIME]['H'] =& hour;
	fingerprints[TIME]['L'] =& useLocal;
	fingerprints[TIME]['M'] =& minute;
	fingerprints[TIME]['O'] =& month;
	fingerprints[TIME]['S'] =& second;
	fingerprints[TIME]['W'] =& dayOfWeek;
	fingerprints[TIME]['Y'] =& year;
}

bool utc = false;
void useGMT()   { utc = true;  }
void useLocal() { utc = false; }

template TimeFunc(char[] internal_f, char[] f, char[] offset = "0") {
	const TimeFunc =
		"void " ~ internal_f ~ "() {"
		"	ip.stack.push(cast(cell)((utc ? Clock.now : WallClock.now).time." ~f~ " + " ~offset~ "));"
		"}"
	;
}
template DateFunc(char[] internal_f, char[] f, char[] offset = "0") {
	const DateFunc =
		"void " ~ internal_f ~ "() {"
		"	ip.stack.push(cast(cell)(Gregorian.generic." ~f~ "(utc ? Clock.now : WallClock.now) + " ~offset~ "));"
		"}"
	;
}

mixin (DateFunc!("day",       "getDayOfMonth"));
mixin (DateFunc!("dayOfYear", "getDayOfYear", "-1"));
mixin (TimeFunc!("hour",      "hours"));
mixin (TimeFunc!("minute",    "minutes"));
mixin (DateFunc!("month",     "getMonth"));
mixin (TimeFunc!("second",    "seconds"));
mixin (DateFunc!("dayOfWeek", "getDayOfWeek", "1"));
mixin (DateFunc!("year",      "getYear"));
