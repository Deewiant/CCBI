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
		detectInfiniteLoops = false,
		allFingsDisabled    = false, // Short-cut past enabledFings if true
		sandboxMode         = false;

	BitFields!(ALL_FINGERPRINT_IDS) enabledFings;
}
