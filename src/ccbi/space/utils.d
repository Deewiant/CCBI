// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2009-09-20 12:03:27

module ccbi.space.utils;

import tango.core.Exception : onOutOfMemoryError;
import tango.stdc.stdlib    : malloc, realloc;

import ccbi.stdlib : modDiv;
import ccbi.space.coords;

template Dimension(cell dim) {
	template Coords(cell x, cell y, cell z) {
		// Using {x} instead of Coords(x) and type inference is:
		// WORKAROUND: http://d.puremagic.com/issues/show_bug.cgi?id=4036
		     static if (dim == 1) const .Coords!(dim) Coords = {x};
		else static if (dim == 2) const .Coords!(dim) Coords = {x,y};
		else static if (dim == 3) const .Coords!(dim) Coords = {x,y,z};
	}
	template Coords(cell x, cell y) { const Coords = Coords!(x,y,0); }
	template Coords(cell x)         { const Coords = Coords!(x,0,0); }

	package bool contains(
		.Coords!(dim) pos, .Coords!(dim) beg, .Coords!(dim) end)
	{
		foreach (i, x; pos.v)
			if (!(x >= beg.v[i] && x <= end.v[i]))
				return false;
		return true;
	}
}

package:

// We use these for AABB data mainly to keep memory usage in check. Using
// cell[] data, "data.length = foo" appears to keep the original data unfreed
// if a reallocation occurred until at least the next GC. I'm not sure if that
// was the exact cause, but using this instead of the GC can reduce worst-case
// memory usage by up to 50% in some cases. We weren't really utilizing the
// advantages of the GC anyway.
cell* cmalloc(size_t s) {
	auto p = cast(cell*)malloc(s * cell.sizeof);
	if (!p)
		onOutOfMemoryError();
	return p;
}
cell* crealloc(cell* p, size_t s) {
	p = cast(cell*)realloc(p, s * cell.sizeof);
	if (!p)
		onOutOfMemoryError();
	return p;
}

template OneCoordsLoop(
	cell dim,
	char[] c, char[] begC, char[] endC,
	char[] cmp, char[] op,
	char[] f)
{
	static if (dim == 1)
		const OneCoordsLoop =
			`for (`~c~`.x = `~begC~`.x; `~c~`.x `~cmp~endC~`.x; `~c~`.x `~op~`) {`
				~f~
			`}`;
	else static if (dim == 2)
		const OneCoordsLoop =
			`for (`~c~`.y = `~begC~`.y; `~c~`.y `~cmp~endC~`.y; `~c~`.y `~op~`)`;
	else static if (dim == 3)
		const OneCoordsLoop =
			`for (`~c~`.z = `~begC~`.z; `~c~`.z `~cmp~endC~`.z; `~c~`.z `~op~`)`;
}

template CoordsLoop(
	cell dim,
	char[] c, char[] begC, char[] endC,
	char[] cmp, char[] op,
	char[] f)
{
	static if (dim == 0)
		const CoordsLoop = "";
	else
		const CoordsLoop = OneCoordsLoop!(dim,   c, begC, endC, cmp, op, f)
		                 ~    CoordsLoop!(dim-1, c, begC, endC, cmp, op, f);
}

// The number of moves it takes to get from "from" to "to" with delta
// "delta". Returns the number of such solutions.
//
// Since there may be multiple solutions, gives the minimal solution in
// "moves", the number of solutions in "count", and the constant
// increment between the solutions in "increment". The value of increment
// is undefined if the count is zero.
//
// If given a non-null bestMoves, adjusts the count so that all the
// resulting move counts are lesser than it.
ucell getMoves(cell from, cell to, cell delta,
               out ucell moves, out ucell increment, ucell* bestMoves)
out (count) {
	if (count) {
		for (auto i = count; i-- > 1;)
			assert (moves + (i-1)*increment < moves + i*increment);

		if (bestMoves)
			assert (moves + (count-1)*increment < *bestMoves);
	}
} body {
	ucell diff = to - from;

	// Optimization: these are the typical cases
	if (delta == 1) {
		moves = diff;
		return bestMoves && moves >= *bestMoves ? 0 : 1;

	} else if (delta == -1) {
		moves = -diff;
		return bestMoves && moves >= *bestMoves ? 0 : 1;
	} else
		return expensiveGetMoves(diff, delta, moves, increment, bestMoves);
}
ucell expensiveGetMoves(ucell to, cell delta,
                        out ucell moves, out ucell increment, ucell* bestMoves)
{
	ubyte countLg;
	if (!modDiv(cast(ucell)delta, to, moves, countLg))
		return 0;

	auto count = cast(ucell)1 << countLg;
	increment = cast(ucell)1 << (ucell.sizeof*8 - countLg);

	// Ensure the solutions are in order, with moves being minimal.
	//
	// Since the solutions are cyclical, either they are already in order
	// (i.e. moves is the least and moves + (count-1)*increment is the
	// greatest), or there are two increasing substrings.
	//
	// If the first is lesser than the last, they're in order. (If they're
	// equal, count is 1. A singleton is trivially in order.)
	//
	// E.g. [1 2 3 4 5].
	ucell minPos = 0;
	auto last = moves + (count-1)*increment;

	if (moves > last) {
		// Otherwise, we have to find the starting point of the second
		// substring. This binary search does the job.
		//
		// E.g. [3 4 5 1 2] (mod 6).
		ucell low = 1, high = count;
		for (;;) {
			assert (low < high);

			// Since we start at low = 1 and the number of solutions is
			// always a power of two, this is guaranteed to happen
			// eventually.
			if (high - low == 1) {
				minPos = (moves + low*increment > moves + high*increment)
						 ? high : low;
				moves += minPos * increment;
				break;
			}

			auto mid = (low + high) >>> 1;

			auto val = moves + mid*increment;

			if (val > moves)
				low = mid + 1;
			else {
				assert (val < last);
				high = mid;
			}
		}
	}
	if (!bestMoves)
		return count;

	// We have a bestMoves to stay under: reduce count to ensure that we
	// do stay under it.

	// Time for another binary search.
	for (ucell low = 0, high = count;;) {
		assert (low <= high);

		if (high - low <= 1)
			return moves + low*increment >= *bestMoves ? low : high;

		auto mid = (low + high) >>> 1;

		auto val = moves + mid*increment;

		if (val < *bestMoves)
			low = mid + 1;
		else
			high = mid;
	}
}
