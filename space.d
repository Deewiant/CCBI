// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2006-06-09 17:34:29

// Funge-Space.
module ccbi.space;

import tango.stdc.string : memcpy;

public import ccbi.cell;

Befunge98Space space;

struct Befunge98Space {
	bool rowInRange(cellidx y) {
		return (y in space) !is null;
	}
	bool cellInRange(cellidx x, cellidx y) {
		return (x in space[y]) !is null;
	}
	bool inBounds(cellidx x, cellidx y) {
		return (
			x >= begX && x <= endX &&
			y >= begY && y <= endY
		);
	}

	// most of the time we want range checking, unsafeGet is separate
	cell opIndex(cellidx x, cellidx y) {
		if (!rowInRange(y) || !cellInRange(x, y))
			(*this)[x, y] = ' ';

		return unsafeGet(x, y);
	}
	void opIndexAssign(cell c, cellidx x, cellidx y) {
		if (x == lastX && y == lastY)
			lastGet = c;

		space[y][x] = c;
	}

	cell unsafeGet(cellidx x, cellidx y) {
		if (!(x == lastX && y == lastY)) {
			lastX = x;
			lastY = y;
			lastGet = space[y][x];
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
	// thanks to GLFunge98 for the idea
	// lastGet is externally initialized to space[0,0], hence lastX and lastY mustn't be 0
	private cellidx lastX = cellidx.min, lastY = cellidx.max;
	cell lastGet;

	private cell[cellidx][cellidx] space;

	void rehash() { space.rehash; }

	typeof(*this) copy() {
		typeof(*this) cp;
		memcpy(&cp, this, cp.sizeof);

		cp.space = null;
		foreach (i, row; space)
			foreach (j, col; row)
				cp.space[i][j] = col;

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

		assert (!s.rowInRange(666));
		assert (s.rowInRange(66));
		assert (s.cellInRange(55, 66));
		assert (!s.cellInRange(54, 66));
	}
}
