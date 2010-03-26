// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

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
			version (IIPC)
				parentID = 0;

			static if (!befunge93) {
				stack = new typeof(*stack);
				version (MODE)
					*stack = typeof(*stack)(false, stackStats);
				else
					*stack = typeof(*stack)(stackStats);
			} else
				stack = typeof(stack)(stackStats);

			cursor = typeof(cursor)(pos, delta, s);

			informSpace();
		}
		return x;
	}

	version (MODE)
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
			version (MODE)
				bool deque = stack.isDeque;

			alias Stack!(.cell) Ctack;

			if (stackCount > 1) {
				// deep copy stack stack
				auto oldSS = stackStack;
				stackStack = new typeof(*stackStack);
				*stackStack = typeof(*stackStack)(*oldSS);

				foreach (inout stack; *stackStack) {
					version (MODE)
						assert (deque == stack.isDeque);

					auto old = stack;
					stack = new typeof(*stack);

					version (MODE) {
						stack.isDeque = deque;

						if (deque)
							stack.deque = Deque(old.deque);
						else
							stack.stack = Ctack(old.stack);
					} else
						*stack = Ctack(*old);
				}
				stack = stackStack.top;
			} else {
				// deep copy stack, nullify stack stack (which we already copied
				// earlier)
				stackStack = null;

				auto old = stack;
				stack = new typeof(*stack);

				version (MODE) {
					stack.isDeque = deque;

					if (deque)
						stack.deque = Deque(old.deque);
					else
						stack.stack = Ctack(old.stack);
				} else
					*stack = Ctack(*old);
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
			version (IMAP)
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

		static if (befunge93) {
			if (pos.x < 0 || pos.x >= 80 || pos.y < 0 || pos.y >= 25)
				cursor.skipMarkers(delta);
		} else {
			auto c = cell;
			if (c == ' ' || c == ';')
				cursor.skipMarkers(delta);
		}
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

	version (IIPC)
		.cell parentID = void;

	static if (befunge93)
		Stack!(.cell) stack;
	else version (MODE)
		CellContainer* stack;
	else
		Stack!(.cell)* stack;

	static if (!befunge93) {
		Stack!(typeof(stack))* stackStack;
		Stack!(Semantics)*[26] semantics;

		typeof(semantics[0]) requireSems(.cell i, ContainerStats* stats) {
			assert (isSemantics(cast(.cell)(i + 'A')));

			auto sems = semantics[i];
			if (!sems) {
				sems = semantics[i] = new typeof(*sems);
				*sems = typeof(*sems)(stats, 2u);
			}
			return sems;
		}
	}

	version (IMAP)
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

	static if (!befunge93) {
		// WORKAROUND: http://d.puremagic.com/issues/show_bug.cgi?id=3509
		// WORKAROUND: http://d.puremagic.com/issues/show_bug.cgi?id=3510
		//
		// If we check fing!().ipCtor here, it'll result in errors because the
		// contents of fing!() are only valid in FungeMachine.
		//
		// If we check fing!().ipCtor in FungeMachine and try to pass it here, we
		// run into the above two bugs.
		//
		// So screw automation.
		uint _MODE_count = 0, _IMAP_count = 0;
	}

	version (HRTI) {
		StopWatch timer;
		bool timerMarked = false;
	}

	version (TRDS) {
		Coords tardisPos, tardisReturnPos, tardisDelta, tardisReturnDelta;
		ulong tardisTick, tardisReturnTick, jumpedTo, jumpedAt;
	}
}
