// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2007-01-20 21:14:19

module ccbi.fingerprints.rcfunge98.frth;

import ccbi.fingerprint;

mixin (Fingerprint!(
	"FRTH",
	"Some common forth [sic] commands",

	"D", "stackSize",
	"L", "forthRoll",
	"O", "forthOver",
	"P", "forthPick",
	"R", "forthRot"
));

template FRTH() {

void stackSize() { with (*cip.stack) push(cast(cell)size); }

void forthOver() {
	with (*cip.stack) {
		auto b = pop, a = pop;

		push(a, b, a);
	}
}

void forthRot() {
	with (*cip.stack) {
		auto c = pop, b = pop, a = pop;

		push(b, c, a);
	}
}

// copy u-th from top to top
void forthPick() {
	with (*cip.stack) {
		auto u = pop,
		     s = size;

		if (u >= s)
			push(0);
		else
			push(at(s - (u+1)));
	}
}

void forthRoll() {
	with (*cip.stack) {
		auto u = pop,
		     s = size;

		version (MODE)
			auto mode = cip.stack.mode;
		else
			const mode = 0;

		if (u >= 0) {
			// ROLL: move the u'th from the top to the top
			if (u >= s)
				return push(0);

			++u; // Make it an offset from the top
			auto x = at(s - u);

			// If we map over multiple arrays and not just one, we need to
			// remember the last element from the previous one.
			//
			// So that [1 2] [3 4] --> [x 1] [2 3]
			// And not [1 2] [3 4] --> [x 1] [3 3]
			auto last = top;

			// These null function arguments are valid because we know that we
			// can't underflow
			if (mode & QUEUE_MODE) {
				// Move the bottom u elements right by one
				mapFirstN(u, (cell[] a) {
					a[0] = last;
					last = a[$-1];

					memmove(a.ptr + 1, a.ptr, (a.length - 1) * cell.sizeof);
				}, null);
			} else {
				// Move the top u elements left by one
				mapFirstN(u, (cell[] a) {
					a[$-1] = last;
					last = a[0];

					memmove(a.ptr, a.ptr + 1, (a.length - 1) * cell.sizeof);
				}, null);
			}
			// Remove leftover nonsense on stack
			pop(1);

			push(x);
			return;
		}

		// -ROLL: move the top to the u'th from top
		u = -u;
		if (u >= s) {
			// Push u-s zeroes to the bottom, then push the top to the bottom
			//
			// E.g. with u=5: [1 2 3] --> [3 0 0 1 2]
			// Invertmode:    [1 2 3] --> [1 2 0 0 3]

			auto x = pop;

			auto add = u - s + 1;

			// Easy if we have a deque since it supports the stuff directly
			version (MODE) if (isDeque) {
				if (mode & INVERT_MODE) {
					auto p = deque.reserveHead(add);
					p[0..add-1] = 0;
					p[   add-1] = x;
				} else {
					auto p = deque.reserveTail(add);
					p[0]      = x;
					p[1..add] = 0;
				}
				return;
			}

			// With a stack, more pain is involved, but at least we don't have to
			// worry about modes
			assert (mode == 0);

			version (MODE) {} else
				auto stack = cip.stack;

			stack.reserve(add);

			// Move the whole stack to the right by add and write appropriately
			bool calledOnlyOnce = true;
			stack.mapFirstN(stack.size, (cell[] a) {
				assert (calledOnlyOnce);
				calledOnlyOnce = false;

				memmove(a.ptr + add, a.ptr, (a.length - add) * cell.sizeof);
				a[0]      = x;
				a[1..add] = 0;
			}, null);
			return;
		}

		// Simpler: just move directly
		//
		// Normal u=3: [1 2 3 4 5] --> [1 2 5 3 4]
		// Queuemode:  [1 2 3 4 5] --> [2 3 1 4 5]
		auto x = top;
		auto last = at(u-1);

		if (mode & QUEUE_MODE) {
			// Move the bottom u elements left by one
			mapFirstN(u, (cell[] a) {
				a[$-1] = last;
				last = a[0];

				memmove(a.ptr, a.ptr + 1, (a.length - 1) * cell.sizeof);
			}, null);

		} else {
			// Move the top u elements right by one
			mapFirstN(u, (cell[] a) {
				a[0] = last;
				last = a[$-1];

				memmove(a.ptr + 1, a.ptr, (a.length - 1) * cell.sizeof);
			}, null);
		}

		setAt(u-1, x);
	}
}

}
