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

template DateTimeFunc(char[] internal_f, char[] f, char[] offset = "0") {
	const DateTimeFunc =
		"void " ~ internal_f ~ "() {"
		"	if (utc) ip.stack.push(cast(cell)(    Clock." ~ f ~ " + " ~ offset ~ "));"
		"	else     ip.stack.push(cast(cell)(WallClock." ~ f ~ " + " ~ offset ~ "));"
		"}"
	;
}

mixin (DateTimeFunc!("day",       "toDate.date.day"));
mixin (DateTimeFunc!("dayOfYear", "toDate.date.doy"));
mixin (DateTimeFunc!("hour",      "now.time.hours"));
mixin (DateTimeFunc!("minute",    "now.time.minutes"));
mixin (DateTimeFunc!("month",     "toDate.date.month"));
mixin (DateTimeFunc!("second",    "now.time.seconds"));
mixin (DateTimeFunc!("dayOfWeek", "toDate.date.dow", "1"));
mixin (DateTimeFunc!("year",      "toDate.date.year"));
