// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2006-06-12 11:24:55

// The Instruction Pointer.
module ccbi.ip;

import tango.core.Tuple;
import tango.time.StopWatch;
import tango.time.Time;

public import ccbi.cell;
       import ccbi.container;
       import ccbi.fingerprint;
       import ccbi.space;
       import ccbi.stats;
       import ccbi.templateutils : EmitGot;
       import ccbi.utils;

final class IP(cell dim, bool befunge93, fings...) {
	alias   .Coords!(dim) Coords;
	alias Dimension!(dim).Coords InitCoords;

	mixin (EmitGot!("HRTI", fings));
	mixin (EmitGot!("IIPC", fings));
	mixin (EmitGot!("IMAP", fings));
	mixin (EmitGot!("TRDS", fings));

	this(
		FungeSpace!(dim, befunge93) s,
		ContainerStats* stackStats,
		ContainerStats* stackStackStats,
		ContainerStats* dequeStats,
		ContainerStats* semanticStats)
	{
		id = 0;
		static if (GOT_IIPC)
			parentID = 0;

		stackStack = new typeof(stackStack)(stackStackStats, 1u);
		stack      = new Stack!(cell)(stackStats);
		stackStack.push(stack);

		static if (GOT_IMAP)
			foreach (j, inout i; mapping)
				i = cast(cell)j;

		foreach (inout sem; semantics)
			sem = new typeof(sem)(semanticStats);

		space = s;
	}

	this(IP o) {
		shallowCopy(this, o);

		static if (GOT_IIPC)
			parentID = o.id;

		// deep copy stack stack
		stackStack = new typeof(stackStack)(o.stackStack);

		bool deque = cast(Deque)stack !is null;

		foreach (inout stack; stackStack) {
			alias Container!(cell) CC;
			alias Stack    !(cell) Ctack;

			stack = (deque
				? cast(CC)new Deque(cast(Deque)stack)
				: cast(CC)new Ctack(cast(Ctack)stack)
			);
		}
		stack = stackStack.top;

		// deep copy semantics
		foreach (i, inout sem; semantics)
			sem = new typeof(sem)(o.semantics[i]);
	}

	void move() {
		auto next = pos; next += delta;

		if (!space.inBounds(next)) {
			do next -= delta;
			while (space.inBounds(next));
			next += delta;
		}

		pos = next;
	}

	void reverse() { delta *= -1; }

	// eat spaces and semicolons, the zero-tick instructions
	void gotoNextInstruction() {
		if (mode & STRING) {
			if (space[pos] == ' ') {
				// SGML spaces: move past all but one space
				Coords next = void;
				do {
					next = pos;
					move();
				} while (space[pos] == ' ');

				pos = next;
			}
		} else for (;;) {
			if (space[pos] == ' ') {
				// no operation until next non-' ', takes no time
				do move();
				while (space[pos] == ' ');
			}

			if (space[pos] == ';') {
				// no operation until next ';', takes no time
				do move();
				while (space[pos] != ';');
				move();
			} else break;
		}
	}

	Container!(cell) newStack() {
		return (cast(Deque)stack
			? cast(Container!(cell))new Deque       (stack.stats)
			: cast(Container!(cell))new Stack!(cell)(stack.stats)
		);
	}

	FungeSpace!(dim, befunge93) space;

	Coords
		pos    = InitCoords!(0),
		delta  = InitCoords!(1),
		offset = InitCoords!(0),
		breakPt;

	cell id = void;

	static if (GOT_IIPC)
		cell parentID = void;

	Container!(cell)      stack;
	Stack!(typeof(stack)) stackStack;
	Stack!(Semantics)[26] semantics;

	static if (GOT_IMAP)
		cell[256] mapping = void;

	enum : typeof(mode) {
		STRING        = 1 << 0,
		BREAK_SET     = 1 << 1,
		HOVER         = 1 << 2, // these two for MODE
		SWITCH        = 1 << 3,
		DORMANT       = 1 << 4, // for IIPC
		ABS_SPACE     = 1 << 5, // the rest for TRDS
		SPACE_SET     = 1 << 6,
		ABS_TIME      = 1 << 7,
		TIME_SET      = 1 << 8,
		DELTA_SET     = 1 << 9,
		SUBR_RELATIVE = 1 << 10, // for SUBR

		FROM_FUTURE = 1 << 11 // for tracing TRDS
	}

	ushort mode = 0;

	static if (GOT_HRTI) {
		StopWatch timer;
		bool timerMarked = false;
	}

	static if (GOT_TRDS) {
		Coords tardisPos, tardisReturnPos, tardisDelta, tardisReturnDelta;
		long tardisTick, tardisReturnTick, jumpedTo, jumpedAt;
	}
}
