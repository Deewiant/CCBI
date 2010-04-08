// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2009-05-13 19:37:44

module ccbi.fungestate;

import tango.core.Tuple;

import ccbi.cell;
import ccbi.container : UDLL;
import ccbi.fingerprints.all;
import ccbi.ip;
import ccbi.space.space;

// All state that should be restored when an IP travels to the past belongs
// here.
struct FungeState(cell dim, bool befunge93) {
	alias .Coords!(dim)             Coords;
	alias .IP    !(dim, befunge93)* IP;

	static if (befunge93)
		alias Tuple!() fings;
	else
		alias ALL_FINGERPRINTS fings;

	FungeSpace!(dim, befunge93) space = void;

	static if (!befunge93) {
		UDLL!(IP, 16) ips;

		version (TRDS) {
			bool useStartIt = false;
			typeof(ips).Iterator startIt = void;
		}

		// For IPs
		cell currentID = 0;
	}

	ulong tick = 0;

	version (REFC)
		Coords[] references;

	version (SUBR) {
		cell[] callStack;
		size_t cs;
	}

	version (TIME)
		bool utc = false;

	version (TRDS)
		IP timeStopper = null;

	// Since we need to pass the address of the space to the IPs when
	// deepCopying, we need to take the target address to write to here.
	void deepCopyTo(typeof(this) copy, bool active = false) {
		*copy = *this;
		with (*copy) {
			space = space.deepCopy();

			static if (!befunge93) {
				assert (ips.length > 0);
				ips = typeof(ips)(ips.length);
				auto cit =      ips.first;
				auto tit = this.ips.first;
				do {
					cit.val = tit.val.deepCopy(active, &space);
					cit++;
					tit++;
				} while (tit.ok);
			}

			version (REFC) references = references.dup;
			version (SUBR) callStack  =  callStack.dup;
		}
	}
	void free() {
		space.free();
		static if (!befunge93)
			ips.free();
	}
}
