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
       import ccbi.fingerprints.all;
       import ccbi.stats;
       import ccbi.templateutils : EmitGot;
       import ccbi.utils;
       import ccbi.space.cursor;

struct IP(cell dim, bool befunge93) {
	alias .Coords    !(dim)            Coords;
	alias  Dimension !(dim).Coords     InitCoords;
	alias .FungeSpace!(dim, befunge93) FungeSpace;

	static if (befunge93)
		alias Tuple!() fings;
	else
		alias ALL_FINGERPRINTS fings;

	mixin (EmitGot!("HRTI", fings));
	mixin (EmitGot!("IIPC", fings));
	mixin (EmitGot!("IMAP", fings));
	mixin (EmitGot!("TRDS", fings));

	// Yes, IPs are always heap-allocated: simplifies things
	static typeof(this) opCall(
		Coords pos,
		FungeSpace* s,
		ContainerStats* stackStats,
		ContainerStats* semanticStats)
	{
		auto x = new IP;
		with (*x) {
			static if (!befunge93)
				id = 0;
			static if (GOT_IIPC)
				parentID = 0;

			stack = new Stack!(.cell)(stackStats);

			static if (!befunge93)
				foreach (inout sem; semantics)
					sem = new typeof(sem)(semanticStats, 2u);

			cursor = typeof(cursor)(pos, delta, s);

			informSpace();
		}
		return x;
	}

	static if (!befunge93)
	typeof(this) deepCopy(bool active = true, FungeSpace* s = null) {
		auto copy = new IP;
		*copy = *this;

		with (*copy) {
			alias Container!(.cell) CC;
			alias Stack    !(.cell) Ctack;

			bool deque = cast(Deque)stack !is null;

			if (stackCount > 1) {
				// deep copy stack stack
				stackStack = new typeof(stackStack)(stackStack);

				foreach (inout stack; stackStack) {
					assert(deque == (cast(Deque)stack !is null));
					stack = deque
						? cast(CC)new Deque(*cast(Deque*)&stack)
						: cast(CC)new Ctack(*cast(Ctack*)&stack);
				}

				stack = stackStack.top;
			} else {
				// deep copy stack
				stack = deque
					? cast(CC)new Deque(*cast(Deque*)&stack)
					: cast(CC)new Ctack(*cast(Ctack*)&stack);
			}

			// deep copy semantics
			foreach (ref sem; semantics)
				sem = new typeof(sem)(sem);

			// deep copy mapping
			static if (GOT_IMAP)
				mapping = mapping.dup;

			if (s)
				cursor.space = s;

			if (active) {
				cursor.invalidate;
				informSpace();
			}
		}
		return copy;
	}

	private void informSpace() {
		cursor.space.addInvalidatee(&cursor.invalidate);
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

	static if (!befunge93)
	size_t stackCount() {
		return stackStack ? stackStack.size : 1;
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
		Stack!(typeof(stack)) stackStack = null;
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
