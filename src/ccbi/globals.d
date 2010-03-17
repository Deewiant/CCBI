// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2008-08-17 11:23:07

module ccbi.globals;

import ccbi.cell;
import ccbi.templateutils : HexCode, Power, WordWrapFromTo;
import ccbi.fingerprints.all;

const cell
	HANDPRINT      = HexCode!("CCBI"),
	VERSION_NUMBER = ParseVersion!(VERSION_END);

version (Win32)
	const cell PATH_SEPARATOR = '\\';
else
	const cell PATH_SEPARATOR = '/';

version (TURT) {
	const TURT_FILE_INIT = "CCBI_TURT.svg";
	char[] turtFile = TURT_FILE_INIT;
}

private template ParseVersion(char[] s) {
	const ParseVersion = ActualParseVersion!(StripNonVersion!(s, ""));
}
private template ActualParseVersion(char[] s) {
	static if (s.length == 0)
		const ActualParseVersion = 0;
	else {
		static assert (s[0] >= '0' && s[0] <= '9');
		const ActualParseVersion =
			Power!(int, 10, s.length-1)*(s[0] - '0')
			+ ActualParseVersion!(s[1..$]);
	}
}
private template StripNonVersion(char[] s, char[] v) {
	static if (s.length == 0)
		const StripNonVersion = v;
	else static if (s[0] == '.')
		const StripNonVersion = StripNonVersion!(s[1..$], v);
	else static if (s[0] >= '0' && s[0] <= '9')
		const StripNonVersion = StripNonVersion!(s[1..$], v ~ s[0]);
	else
		const StripNonVersion = StripNonVersion!(s[1..$], "");
}

private const char[] VERSION_END = "Interpreter version 2.0.0";

// Yay version combinations and --version strings
version (unefunge98) version ( befunge98) version = funge98Multi;
version  (befunge98) version (trefunge98) version = funge98Multi;
version (trefunge98) version (unefunge98) version = funge98Multi;

private char[] FEATURES() {
	char[] s = "Features:";

	version (unefunge98)          s ~= " Unefunge-98,";
	version  (befunge98)          s ~= " Befunge-98,";
	version (trefunge98)          s ~= " Trefunge-98,";
	version  (befunge93)          s ~= " Befunge-93,";
	version (statistics)          s ~= " statistics,";
	version (tracer)              s ~= " tracer,";
	version (detectInfiniteLoops) s ~= " extra infinite loop detection,";

	s = "\n" ~ WordWrapFromTo(1, 11, s[0..$-1] ~ ".");

	if (ALL_FINGERPRINTS.length > 0) {
		char[] f = "Fingerprints:";
		foreach (fing; ALL_FINGERPRINTS)
			f ~= " " ~ fing ~ ",";
		s ~= "\n" ~ WordWrapFromTo(1, 15, f[0..$-1] ~ ".");
	}
	return s;
}

version (funge98Multi)
	const char[] VERSION_STRING =
		"CCBI - Conforming Concurrent Funge-98 " ~ VERSION_END ~ FEATURES;
else version (befunge98)
	const char[] VERSION_STRING =
		"CCBI - Conforming Concurrent Befunge-98 " ~ VERSION_END ~ FEATURES;
else version (trefunge98)
	const char[] VERSION_STRING =
		"CCBI - Conforming Concurrent Trefunge-98 " ~ VERSION_END ~ FEATURES;
else version (unefunge98)
	const char[] VERSION_STRING =
		"CCBI - Conforming Concurrent Unefunge-98 " ~ VERSION_END ~ FEATURES;
else
	const char[] VERSION_STRING =
		"CCBI - Conforming Concurrent Befunge-93 " ~ VERSION_END ~ FEATURES;
