// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:12:24

module ccbi.fingerprints.rcfunge98.base;

import tango.core.BitManip : bsr;

import ccbi.fingerprint;

// 0x42415345: BASE
// I/O for numbers in other bases
// ------------------------------

mixin (Fingerprint!(
	"BASE",

	"B", "output!(`b`)",
	"H", "output!(`x`)",
	"I", "inputBase",
	"N", "outputBase",
	"O", "output!(`o`)"
));

bool contains(char[] a, char b) {
	foreach (c; a)
		if (c == b)
			return true;
	return false;
}

uint floorLog(uint base, uint val) {
	// bsr is just an integer log2
	return bsr(val) / bsr(base);
}

template BASE() {

import tango.text.convert.Integer : intToString = toString;
import tango.text.Util            : repeat;

void output(char[] fmt)() {
	static if (GOT_TRDS)
		if (tick < ioAfter)
			return cip.stack.pop(1);

	Sout(intToString(cip.stack.pop, fmt));
	ubyte b = ' ';
	Cout.write(b);
}

void outputBase() {
	auto base = cip.stack.pop,
	     val  = cip.stack.pop;

	if (base <= 0 || base > 36)
		return reverse();

	static if (GOT_TRDS)
		if (tick < ioAfter)
			return;

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

	Sout(result[0..i].reverse);
	ubyte b = ' ';
	Cout.write(b);
}

void inputBase() {
	auto base = cip.stack.pop;

	if (base <= 0 || base > 36)
		return reverse();

	static if (GOT_TRDS)
		if (tick < ioAfter)
			return cip.stack.push(0);

	Sout.flush();

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
		while (!digits.contains(c));
	} catch {
		return reverse();
	}

	cunget();

	cell n = 0;
	auto s = new char[80];
	size_t j;

	try {
		for (;;) {
			c = toLower(cget());

			if (!digits.contains(c))
				break;

			if (j == s.length)
				s.length = 2 * s.length;

			s[j++] = c;

			cell tmp = 0;

			// value of characters read so far, in base
			foreach_reverse (i, ch; s[0..j])
				tmp += ipow(base, j-i-1) * (ch < 'a' ? ch - '0' : ch - 'a' + 10);

			// oops, overflow, stop here
			if (tmp < 0)
				break;

			n = tmp;
		}

		// put back eaten char if it wasn't line break
		if (c == '\r') {
			if (cget() != '\n')
				cunget();
		} else if (c != '\n')
			cunget();
	} catch {
		return reverse();
	}

	cip.stack.push(n);
}

}
