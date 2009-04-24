// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:13:48

module ccbi.fingerprints.rcfunge98.evar; private:

import tango.stdc.stringz : toStringz;
import tango.text.Ascii   : icompare;

version (Win32)
	import tango.sys.win32.UserGdi : SetEnvironmentVariableA;
else version (Posix)
	import tango.stdc.posix.stdlib : setenv;
else
	static assert (false, "No setenv for non-Win32 and non-Posix");

import ccbi.fingerprint;
import ccbi.instructions : reverse;
import ccbi.ip;
import ccbi.utils;

// 0x45564152: EVAR
// Environment variables extension
// -------------------------------

static this() {
	mixin (Code!("EVAR"));

	fingerprints[EVAR]['G'] =& getEnv;
	fingerprints[EVAR]['N'] =& getEnvCount;
	fingerprints[EVAR]['P'] =& putEnv;
	fingerprints[EVAR]['V'] =& getNthEnv;
}

private size_t getEqualsSign(char[] s) {
	foreach (i, c; s)
	if (c == '=')
		return i;
	return s.length;
}

void getEnv() {
	auto s = popString();

	foreach (v; environment()) {
		auto i = getEqualsSign(v);

		// Windows isn't case sensitive...
		version (Win32) {
			if (icompare(v[0..i], s) == 0)
				return pushStringz(v[i+1..$]);

		} else {
			if (v[0..i] == s)
				return pushStringz(v[i+1..$]);
		}
	}
	reverse();
}

void getEnvCount() {
	ip.stack.push(cast(cell)environment().length);
}

void putEnv() {
	auto s = popString!(true)();

	auto idx = getEqualsSign(s);

	if (idx == s.length)
		return reverse();
	else {
		version (Win32) {
			if (!SetEnvironmentVariableA(toStringz(s[0..idx]), s[idx+1..$].ptr))
				return reverse();
		} else {
			if (setenv(toStringz(s[0..idx]), s[idx+1..$].ptr, 1) == -1)
				return reverse();
		}
	}

	envChanged = true;
}

void getNthEnv() {
	auto env = environment(),
	       n = ip.stack.pop;

	if (n >= env.length)
		return reverse();

	pushStringz(env[n]);
}
