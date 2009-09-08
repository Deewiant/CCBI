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
		Coords pos,
		FungeSpace!(dim, befunge93) s,
		ContainerStats* stackStats,
		ContainerStats* stackStackStats,
		ContainerStats* semanticStats)
	{
		static if (!befunge93)
			id = 0;
		static if (GOT_IIPC)
			parentID = 0;

		stack = new Stack!(.cell)(stackStats);

		static if (!befunge93) {
			stackStack = new typeof(stackStack)(stackStackStats, 1u);
			stackStack.push(stack);
		}

		static if (!befunge93)
			foreach (inout sem; semantics)
				sem = new typeof(sem)(semanticStats);

		cursor = typeof(cursor)(pos, &delta, s);
		s.informOf(&cursor);
	}

	static if (!befunge93) this(IP o) {
		shallowCopy(this, o);

		// deep copy stack stack
		stackStack = new typeof(stackStack)(o.stackStack);

		bool deque = cast(Deque)stack !is null;

		foreach (inout stack; stackStack) {
			alias Container!(.cell) CC;
			alias Stack    !(.cell) Ctack;

			stack = (deque
				? cast(CC)new Deque(cast(Deque)stack)
				: cast(CC)new Ctack(cast(Ctack)stack)
			);
		}
		stack = stackStack.top;

		// deep copy semantics
		foreach (i, inout sem; semantics)
			sem = new typeof(sem)(o.semantics[i]);

		// deep copy mapping
		static if (GOT_IMAP)
			mapping = o.mapping.dup;
	}

	void   move()         { cursor.advance(delta); }
	void unmove()         { cursor.retreat(delta); }
	void   move(Coords d) { cursor.advance(d); }

	void reverse() { delta *= -1; }

	void gotoNextInstruction() {
		mode & STRING
			? cursor.skipToLastSpace(delta)
			: cursor.skipMarkers    (delta);
	}

	Container!(.cell) newStack() {
		return (cast(Deque)stack
			? cast(Container!(.cell))new Deque        (stack.stats)
			: cast(Container!(.cell))new Stack!(.cell)(stack.stats)
		);
	}

	Coords pos()         { return cursor.pos; }
	void   pos(Coords c) { return cursor.pos = c; }

	.cell       cell()        { return cursor.      get(); }
	.cell unsafeCell()        { return cursor.unsafeGet(); }
	void        cell(.cell c) { return cursor.      set(c); }
	void  unsafeCell(.cell c) { return cursor.unsafeSet(c); }

	Cursor!(dim, befunge93) cursor;
	Coords delta = InitCoords!(1);

	static if (!befunge93)
		Coords offset = InitCoords!(0);

	static if (!befunge93)
		.cell id = void;

	static if (GOT_IIPC)
		.cell parentID = void;

	Container!(.cell) stack;

	static if (!befunge93) {
		Stack!(typeof(stack)) stackStack;
		Stack!(Semantics)[26] semantics;
	}

	static if (GOT_IMAP)
		.cell[] mapping;

	enum : typeof(mode) {
		STRING        = 1 << 0,
		HOVER         = 1 << 1, // these two for MODE
		SWITCH        = 1 << 2,
		DORMANT       = 1 << 3, // for IIPC
		ABS_SPACE     = 1 << 4, // these for TRDS
		SPACE_SET     = 1 << 5,
		ABS_TIME      = 1 << 6,
		TIME_SET      = 1 << 7,
		DELTA_SET     = 1 << 8,
		NEG_TIME      = 1 << 9, // only applies when not ABS_TIME
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
		ulong tardisTick, tardisReturnTick, jumpedTo, jumpedAt;
	}
}
