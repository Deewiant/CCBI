// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2008-08-17 11:23:07

module ccbi.globals;

import ccbi.cell;
import ccbi.templateutils;

// Yay version combinations and --version strings
version (unefunge98) version ( befunge98) version = funge98_12;
version ( befunge98) version (trefunge98) version = funge98_23;
version (trefunge98) version (unefunge98) version = funge98_13;

version (funge98_12) version = funge98Multi;
version (funge98_23) version = funge98Multi;
version (funge98_13) version = funge98Multi;

version (funge98Multi)
	const char[] VERSION_STRING =
		"CCBI - Conforming Concurrent Funge-98 Interpreter version 2.0.0";
else version (befunge98)
	const char[] VERSION_STRING =
		"CCBI - Conforming Concurrent Befunge-98 Interpreter version 2.0.0";
else version (trefunge98)
	const char[] VERSION_STRING =
		"CCBI - Conforming Concurrent Trefunge-98 Interpreter version 2.0.0";
else version (unefunge98)
	const char[] VERSION_STRING =
		"CCBI - Conforming Concurrent Unefunge-98 Interpreter version 2.0.0";
else
	const char[] VERSION_STRING =
		"CCBI - Conforming Concurrent Befunge-93 Interpreter version 2.0.0";

const cell
	HANDPRINT      = HexCode!("CCBI"),
	VERSION_NUMBER = ParseVersion!(VERSION_STRING);

version (Win32)
	const cell PATH_SEPARATOR = '\\';
else
	const cell PATH_SEPARATOR = '/';
