// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-06-16 14:30:04

module ccbi.mini.vars;

import ccbi.ip;
import ccbi.space;

// "real IP" OWTTE
IP* rip;
typeof(space)* mSpace;
bool
	mOver = false,
	mNeedMove = true,
	useMiniFunge = true;

// needed by ccbi.ccbi as well as ccbi.mini.funge, might as well be here
bool warnings = false;

enum Mini : byte {
	UNIMPLEMENTED,
	NONE,
	ALL
}
Mini miniMode;
