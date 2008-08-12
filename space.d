// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2006-06-09 17:34:29

// Funge-Space.
module ccbi.space;

import tango.stdc.string : memcpy;

public import ccbi.cell;

Befunge98Space space;

private struct CoordPair {
	cellidx x, y;

	// MurmurHash 2.0, thanks to Austin Appleby
	// at http://murmurhash.googlepages.com/
	static assert (cellidx.sizeof == 4);
	hash_t toHash() {
		const hash_t m = 0x_5bd1_e995;

		hash_t h = 0x7fd6_52ad ^ (x.sizeof + y.sizeof), k;

		k = x; k *= m; k ^= k >> 24; k *= m; h *= m; h ^= k;
		k = y; k *= m; k ^= k >> 24; k *= m; h *= m; h ^= k;

		h ^= h >> 13;
		h *= m;
		h ^= h >> 15;

		return h;
	}
}

struct Befunge98Space {
	bool cellInRange(cellidx x, cellidx y) {
		return (CoordPair(x, y) in space) !is null;
	}
	bool inBounds(cellidx x, cellidx y) {
		return (
			x >= begX && x <= endX &&
			y >= begY && y <= endY
		);
	}

	// most of the time we want range checking, unsafeGet is separate
	cell opIndex(cellidx x, cellidx y) {
		if (!cellInRange(x, y)) {
			(*this)[x, y] = ' ';
			return ' ';
		}

		return unsafeGet(x, y);
	}
	void opIndexAssign(cell c, cellidx x, cellidx y) {
		if (x == lastX && y == lastY)
			lastGet = c;

		space[CoordPair(x, y)] = c;
	}

	cell unsafeGet(cellidx x, cellidx y) {
		if (!(x == lastX && y == lastY)) {
			lastX = x;
			lastY = y;
			lastGet = space[CoordPair(x, y)];
		}
		return lastGet;
	}

	// i.e. the x of the left/rightmost non-space char
	//  and the y of the highest/lowest non-space char
	// these are array indices, starting from 0
	// thus the in-use map size is (endX - begX + 1) * (endY - begY + 1)
	// begY must start at 0 or the first row of the program loops infinitely
	// but begX has to be found out: make it doable with less than -checks
	cellidx
		begX = cellidx.max,
		begY = 0,
		endX,
		endY;

	// cache the last get, speeds up most programs
	// lastGet is externally initialized to space[0,0], hence these two mustn't be 0,0
	private cellidx lastX = cellidx.max, lastY = cellidx.min;
	cell lastGet;

	private cell[CoordPair] space;

	typeof(*this) copy() {
		typeof(*this) cp;
		memcpy(&cp, this, cp.sizeof);

		cp.space = null;
		foreach (k, v; space)
			cp.space[k] = v;

		return cp;
	}

	unittest {
		typeof(*this) s;

		s[55, 66] = 's';
		assert (s[55, 66] == 's');

		s[44, -66] = 't';
		assert (s[44, -66] == 't');

		s[-33, 55] = 'u';
		assert (s[-33, 55] == 'u');

		s[-22, -11] = 'v';
		assert (s[-22, -11] == 'v');

		s[cellidx.max, cellidx.max] = 'w';
		assert (s[cellidx.max, cellidx.max] == 'w');

		assert (s[1234, 4321] == ' ');
		assert (s.unsafeGet(1234, 4321) == ' ');

		assert (s[-1, -2] == ' ');
		assert (s.unsafeGet(-1, -2) == ' ');

		s[-1, -1] = 5;
		assert (s.unsafeGet(-1, -1) == 5);

		assert (s.unsafeGet(-1, -2) == ' ');

		assert (s.cellInRange(55, 66));
		assert (!s.cellInRange(54, 66));
	}
}
