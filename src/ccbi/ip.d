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
		ContainerStats* stackStats)
	{
		auto x = new IP;
		with (*x) {
			static if (!befunge93)
				id = 0;
			static if (GOT_IIPC)
				parentID = 0;

			static if (!befunge93) {
				stack = new typeof(*stack);
				*stack = typeof(*stack)(false, stackStats);
			} else
				stack = typeof(stack)(stackStats);

			cursor = typeof(cursor)(pos, delta, s);

			informSpace();
		}
		return x;
	}

	static if (!befunge93)
	invariant {
		if (this.stackStack)
			foreach (stack; *stackStack)
				assert (stack.isDeque == this.stack.isDeque);
	}

	static if (!befunge93)
	typeof(this) deepCopy(bool active = true, FungeSpace* s = null) {
		auto copy = new IP;
		*copy = *this;

		with (*copy) {
			bool deque = stack.isDeque;

			alias Stack!(.cell) Ctack;

			if (stackCount > 1) {
				// deep copy stack stack
				auto oldSS = stackStack;
				stackStack = new typeof(*stackStack);
				*stackStack = typeof(*stackStack)(*oldSS);

				foreach (inout stack; *stackStack) {
					assert (deque == stack.isDeque);
					auto old = stack;
					stack = new typeof(*stack);
					stack.isDeque = deque;
					if (deque)
						stack.deque = Deque(old.deque);
					else
						stack.stack = Ctack(old.stack);
				}
				stack = stackStack.top;
			} else {
				// deep copy stack, nullify stack stack (which we already copied
				// earlier)
				stackStack = null;

				auto old = stack;
				stack = new typeof(*stack);
				stack.isDeque = deque;
				if (deque)
					stack.deque = Deque(old.deque);
				else
					stack.stack = Ctack(old.stack);
			}

			// deep copy semantics
			foreach (ref sem; semantics) {
				if (sem && !sem.empty) {
					auto old = sem;
					sem = new typeof(*sem);
					*sem = typeof(*sem)(*old);
				}
			}

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
		static if (!befunge93)
			if (mode & STRING)
				return cursor.skipToLastSpace(delta);

		cursor.skipMarkers(delta);
	}

	static if (!befunge93)
	size_t stackCount()
	out (result) {
		assert (result >= 1);
	} body {
		return stackStack ? stackStack.size : 1;
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

	static if (befunge93)
		Stack!(.cell) stack;
	else
		CellContainer* stack;

	static if (!befunge93) {
		Stack!(CellContainer*)* stackStack;
		Stack!(Semantics)*[26] semantics;
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
