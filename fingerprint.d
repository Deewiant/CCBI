// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 20:13:49

// Stuff related to fingerprints, and some Mini-Funge variables which have to
// be defined outside ccbi.minifunge to avoid circular dependencies.
module ccbi.fingerprint;

import ccbi.cell;
import ccbi.stdlib;

void function()[][cell] fingerprints;
void function()  [cell] fingerprintConstructors;
void function()  [cell] fingerprintDestructors;

// the number of times a fingerprint is loaded
// so that the destructor is called only when the loaded count is zero
uint             [cell] fingerprintLoaded;

template Code(char[4] s, char[] id = s) {
	const Code =
		"const cell " ~ id ~ " = " ~ ToUtf8!(HexCode!(s)) ~ ";" ~
		// this really shouldn't be here, but oh well
		"fingerprints[" ~ ToUtf8!(HexCode!(s)) ~ "] = " ~
		"new typeof(fingerprints[" ~ ToUtf8!(HexCode!(s)) ~ "])('Z'+1);";
}

template HexCode(char[4] s) {
	const uint HexCode = s[3] | (s[2] << 8) | (s[1] << 16) | (s[0] << 24);
}

static assert (HexCode!("ASDF") == 0x_41_53_44_46);

enum : bool {
	BUILTIN,
	MINI
}

struct Semantics {
	bool type;
	union {
		void function() instruction;
		void delegate() miniFunge;
	}

	static typeof(*this) opCall(bool t, typeof(instruction) i) {
		typeof(*this) s;
		with (s) {
			type = t;
			instruction = i;
		}
		return s;
	}
	static typeof(*this) opCall(bool t, typeof(miniFunge) m) {
		typeof(*this) s;
		with (s) {
			type = t;
			miniFunge = m;
		}
		return s;
	}
}
