// File created: 2009-05-13 19:37:44

module ccbi.fungestate;

import ccbi.cell;
import ccbi.ip;
import ccbi.space;
import ccbi.templateutils : EmitGot;
import ccbi.utils         : shallowCopy;

// All state that should be restored when an IP travels to the past belongs
// here.
struct FungeState(cell dim, bool befunge93, fings...) {

	alias .IP    !(dim, befunge93, fings) IP;
	alias .Coords!(dim)                   Coords;

	mixin (EmitGot!("REFC", fings));
	mixin (EmitGot!("TURT", fings));
	mixin (EmitGot!("SUBR", fings));
	mixin (EmitGot!("TIME", fings));
	mixin (EmitGot!("TRDS", fings));

	FungeSpace!(dim, befunge93) space;

	static if (!befunge93) {
		IP[] ips;
		size_t startIdx;

		// For IPs
		cell currentID = 0;
	}

	ulong tick = 0;

	static if (GOT_REFC)
		Coords[] references;

	static if (GOT_SUBR) {
		cell[] callStack;
		size_t cs;
	}

	static if (GOT_TIME)
		bool utc = false;

	static if (GOT_TRDS)
		auto timeStopper = size_t.max;

	typeof(*this) deepCopy() {
		typeof(*this) copy = *this;

		with (copy) {
			space = new typeof(space)(space);

			static if (!befunge93) {
				ips = ips.dup;
				foreach (ref ip; ips) {
					ip = new IP(ip);
					ip.cursor.space = space;
				}
			}

			static if (GOT_REFC) references = references.dup;
			static if (GOT_SUBR) callStack  =  callStack.dup;
		}
		return copy;
	}
}
