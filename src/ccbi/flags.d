// File created: 2008-09-05 21:48:48

module ccbi.flags;

import ccbi.fingerprints.all;
import ccbi.stdlib : BitFields;

struct Flags {
	bool
		useStats         = false,
		script           = false,
		tracing          = false,
		warnings         = false,
		allFingsDisabled = false; // Short-cut past enabledFings if true

	BitFields!(ALL_FINGERPRINT_IDS) enabledFings;
}
