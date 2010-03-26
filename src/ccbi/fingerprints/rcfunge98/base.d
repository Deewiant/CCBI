// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2007-01-20 21:12:24

module ccbi.fingerprints.rcfunge98.base;

import tango.core.BitManip : bsr;

import ccbi.fingerprint;

mixin (Fingerprint!(
	"BASE",
	"I/O for numbers in other bases

      'N' and 'I' reverse unless 0 < base < 36.\n",

	"B", "output!(`b`)",
	"H", "output!(`x`)",
	"I", "inputBase",
	"N", "outputBase",
	"O", "output!(`o`)"
));

uint floorLog(uint base, uint val) {
	// bsr is just an integer log2
	return bsr(val) / bsr(base);
}

template BASE() {

import tango.core.Array           : bsearch;
import tango.text.convert.Integer : intToString = toString;
import tango.text.Util            : repeat;

void output(char[] fmt)() {
	version (TRDS)
		if (state.tick < ioAfter)
			return cip.stack.pop(1);

	try Sout(intToString(cip.stack.pop, fmt));
	catch {
		return reverse;
	}
	cput(' ');
}

void outputBase() {
	auto base = cip.stack.pop,
	     val  = cip.stack.pop;

	if (base <= 0 || base > 36)
		return reverse();

	version (TRDS)
		if (state.tick < ioAfter)
			return;

	bool rev = false;

	if (val < 0) {
		val = -val;
		rev = !cputDirect('-');
	}

	const DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz";

	static char[] result;
	size_t i;

	if (base == 1) {
		result = repeat("0", val);
		i = val;
	} else if (!val) {
		result = "0";
		i = 1;
	} else {
		result.length = floorLog(base, val) + 1;
		for (i = 0; val > 0; val /= base)
			result[i++] = DIGITS[val % base];
	}

	foreach_reverse (c; result[0..i])
		if (!cputDirect(c))
			rev = true;
	rev = !cputDirect(' ') || rev;

	if (rev)
		reverse;
}

void inputBase() {
	auto base = cip.stack.pop;

	if (base <= 0 || base > 36)
		return reverse();

	version (TRDS)
		if (state.tick < ioAfter)
			return cip.stack.push(0);

	try Sout.flush(); catch {}

	auto digits = "0123456789abcdefghijklmnopqrstuvwxyz"[0..base];
	char c;

	static char toLower(in char c) {
		if (c >= 'A' && c <= 'Z')
			return c + ('a' - 'A');
		else
			return c;
	}

	try {
		do c = cget();
		while (!digits.bsearch(c));
	} catch {
		return reverse();
	}

	cunget(c);

	cell n = 0;
	auto s = new char[80];
	size_t j;

	reading: for (;;) {
		try c = toLower(cget());
		catch { return cip.stack.push(n); }

		if (!digits.bsearch(c))
			break;

		// Overflow: can't read another char
		if (n > n.max / base)
			break;

		if (j == s.length)
			s.length = 2 * s.length;

		s[j++] = c;

		cell tmp = 0;
		foreach_reverse (i, ch; s[0..j]) {
			auto add = ipow(base, j-i-1) * (ch < 'a' ? ch - '0' : ch - 'a' + 10);

			// Overflow caused by char
			if (tmp > tmp.max - add)
				break reading;

			tmp += add;
		}
		n = tmp;
	}
	cunget(c);

	cip.stack.push(n);
}

}
