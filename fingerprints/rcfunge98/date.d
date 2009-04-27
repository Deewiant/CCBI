// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2008-08-09 20:43:40

module ccbi.fingerprints.rcfunge98.date;

import ccbi.fingerprint;

// WORKAROUND: http://www.dsource.org/projects/dsss/ticket/175
import tango.time.chrono.Gregorian;

// 0x44415445: DATE
// Date Functions
// --------------

mixin (Fingerprint!(
	"DATE",

	"A", "addDays",
	"C", "jdnToYmd",
	"D", "dayDiff",
	"J", "ymdToJdn",
	"T", "yearDayToFull",
	"W", "weekDay",
	"Y", "yearDay"
));

template DATE() {

import tango.math.Math : floor;
import tango.time.Time;
import tango.time.chrono.Gregorian;

Time popYMD() {
	with (cip.stack) {
		cell
			day   = pop(),
			month = pop(),
			year  = pop();

		auto y = absY(year);
		auto e =  era(year);

		if (
			day <= 0 || month <= 0 || month > 12 || !year ||
			day > Gregorian.generic.getDaysInMonth(y, month, e)
		) {
			reverse();
			throw new Object;
		}

		return Gregorian.generic.toTime(y, month, day, 0,0,0,0, e);
	}
}

void pushYMD(Time time) {
	cip.stack.push(
		getYear(time),
		cast(cell)Gregorian.generic.getMonth(time),
		cast(cell)Gregorian.generic.getDayOfMonth(time)
	);
}

cell getYear(Time time) {
	return cast(cell)(
		Gregorian.generic.getEra(time) == Gregorian.BC_ERA
			? -Gregorian.generic.getYear(time)
			:  Gregorian.generic.getYear(time));
}

// Since Tango functions take uint/era instead of int
uint absY(cell year) { return cast(uint)(year < 0 ? -year : year); }
uint era (cell year) { return year < 0 ? Gregorian.BC_ERA : Gregorian.AD_ERA; }

void addDays() {
	cell days = cip.stack.pop();

	try {
		auto time = popYMD();
		time += TimeSpan.fromDays(days);
		pushYMD(time);
	} catch {}
}

void dayDiff() {
	try {
		auto t2 = popYMD().span, t1 = popYMD().span;
		cip.stack.push(cast(cell)((t1 -= t2).days));
	} catch {}
}

void jdnToYmd() {
	auto j = cip.stack.pop();

	auto time = Gregorian.generic.toTime(4714,11,24, 12,0,0,0, Gregorian.BC_ERA);
	time += TimeSpan.fromDays(j);

	pushYMD(time);
}

void ymdToJdn() {
	try {
		auto
			t = popYMD().span,
			epoch = Gregorian.generic.toTime(4714,11,24, 0,0,0,0, Gregorian.BC_ERA).span;

		cip.stack.push(cast(cell)(t - epoch).days);
	} catch {}
}

void yearDayToFull() {
	with (cip.stack) {
		auto
			doy  = pop()+1,
			year = pop();

		if (
			!year ||
			doy <= 0
			|| doy > Gregorian.generic.getDaysInYear(absY(year), era(year))
		)
			return reverse();

		auto time = Time.epoch;
		time  = Gregorian.generic.addYears(time, year-1);
		time += TimeSpan.fromDays(doy-1);

		pushYMD(time);
	}
}

void weekDay() {
	try cip.stack.push(cast(cell)((Gregorian.generic.getDayOfWeek(popYMD())-1) % 7));
	catch {}
}

void yearDay() {
	try cip.stack.push(cast(cell) (Gregorian.generic.getDayOfYear(popYMD())-1));
	catch {}
}

}
