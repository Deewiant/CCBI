// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2008-09-05 21:48:48

module ccbi.flags;

import ccbi.fingerprints.all;
import ccbi.stdlib : BitFields;

struct Flags {
	version (statistics)
		bool useStats = false;
	bool
		script              = false,
		tracing             = false,
		warnings            = false,
		infiniteLoop        = false,
		allFingsDisabled    = false, // Short-cut past enabledFings if true
		sandboxMode         = false;

	BitFields!(ALL_FINGERPRINT_IDS) enabledFings;
}
