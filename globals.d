// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2008-08-17 11:23:07

module ccbi.globals;

import ccbi.cell;
import ccbi.templateutils;

const char[]
	VERSION_STRING =
		"CCBI - Conforming Concurrent Befunge-98 Interpreter version 2.0.0";

const cell
	HANDPRINT      = HexCode!("CCBI"),
	VERSION_NUMBER = ParseVersion!(VERSION_STRING);

version (Win32)
	const cell PATH_SEPARATOR = '\\';
else
	const cell PATH_SEPARATOR = '/';
