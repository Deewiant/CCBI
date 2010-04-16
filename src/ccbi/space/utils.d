// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2009-09-20 12:03:27

module ccbi.space.utils;

import tango.core.Exception : onOutOfMemoryError;
import tango.math.Math      : min, max;
import tango.stdc.stdlib    : malloc, realloc;

import ccbi.stdlib : abs, gcdLog, modDiv;
import ccbi.space.coords;

// Dimension-specific utils
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

package:

	bool contains(.Coords!(dim) pos, .Coords!(dim) beg, .Coords!(dim) end) {
		// Up to 20% improvement from this unrolling alone!
		                    if (!(pos.x >= beg.x && pos.x <= end.x)) return false;
		static if (dim > 1) if (!(pos.y >= beg.y && pos.y <= end.y)) return false;
		static if (dim > 2) if (!(pos.z >= beg.z && pos.z <= end.z)) return false;
		return true;
	}

	bool rayIntersects(
		.Coords!(dim) o, .Coords!(dim) delta,
		.Coords!(dim) beg, .Coords!(dim) end,
		out ucell moveCnt, out .Coords!(dim) at
	)
	out (intersects) {
		assert (!intersects || contains(at, beg, end));
	} body {
		// {{{ Helpers
		static bool matches(ucell moves, cell e1, cell e2, cell from, cell delta)
		{
			if (!delta) {
				// We check that the zero deltas are correct in advance
				return true;
			}
			cell pos = from + moves * delta;
			return pos >= e1 && pos <= e2;
		}
		// The range of possible coordinates in the given range that the given 1D
		// ray can collide with.
		static void getBegEnd(
			cell edge1, cell edge2, cell from, cell delta,
			out cell beg, out cell end)
		{
			if (delta > 0) {
				beg = edge1;
				end = min(beg + delta + 1, edge2);
			} else {
				end = edge2;
				beg = max(end + delta - 1, edge1);
			}
		}
		// }}}

		// Quick check to start with: if we don't move along an axis, we should
		// be in the box along it.
		for (ucell i = 0; i < dim; ++i)
			if (!delta.v[i] && !(o.v[i] >= beg.v[i] && o.v[i] <= end.v[i]))
				return false;

		// {{{ Long explanation
		//
		// The basic idea here: check, for each point in the box, how many steps
		// it takes for the ray to reach it (or whether it can reach it at all).
		// Then select the minimum as the answer and return true (or, if no
		// points can be reached, return false).
		//
		// What could be done for each point is solving dim-1 linear diophantine
		// equations, one for each axis. (See the getMoves() helper.) Thus we'd
		// get dim-1 sets of move counts that would reach that point. The minimal
		// solution for the point is then the minimum of their intersection.
		//
		// As an optimization, note that we only need to solve one equation, then
		// simply try each of the resulting move counts for the other axes,
		// checking whether they also reach the point under consideration.
		//
		// This can be extended to reduce the number of points we have to check,
		// since if we are solving e.g. the equation for the X-coordinate, we
		// obviously need to do it only for points with a different X-coordinate:
		// the equation would be the exact same for the others. Now we are no
		// longer looking at a particular point, rather a line segment within the
		// box. For the other axes, we now only check that their result falls
		// within the box, not caring which particular point it hits. (See the
		// matches() helper.)
		//
		// We've got two alternative approaches based on the above basic ideas:
		//
		// 	1. Realize that the set of points which can actually be reached
		// 	   with a given delta is limited to some points near the edge of
		// 	   the box: if the delta is (1,0), only the leftmost edge of the
		// 	   box can be touched, and thus only they need to be checked. (See
		// 	   the getBegEnd() helper.)
		//
		// 	   The number of different (coordinate, move count) pairs that we
		// 	   have to check in this approach is:
		//
		// 	   sum_i gcd(2^32, delta[i]) * min(|delta[i]|, end[i]-beg[i]+1)
		//
		// 	   (Where gcd(2^32, delta[i]) is the number of move count solutions
		// 	   for axis i, assuming a 32-bit ucell. See helper gcd().)
		//
		// 	2. Realize that checking along one axis is sufficient to find all
		// 	   answers for the whole box. If we go over every solution for
		// 	   every X-coordinate in the box, there is no point in checking
		// 	   other axes, since any solutions for them have to have
		// 	   corresponding solutions in the X-axis.
		//
		// 	   The number of pairs to check here is:
		//
		// 	   min_i gcd(2^32, delta[i]) * (end[i]-beg[i]+1)
		//
		// To minimize the amount of work we have to do, we want to pick the one
		// with less pairs to check. So, when does the following inequality hold,
		// i.e. when do we prefer method 1?
		//
		// min(gx*sx, gy*sy, gz*sz) >   gx*min(sx,|dx|)
		//                            + gy*min(sy,|dy|)
		//                            + gz*min(sz,|dz|)
		//
		// (Where d[xyz] = delta.[xyz], g[xyz] = gcd(2^32, delta.[xyz]), and
		// s[xyz] = end.[xyz]-beg.[xyz]+1.)
		//
		// For this to be true, we want the delta along each axis to be less than
		// the box size along that axis. Consider, if only two deltas out of
		// three are less:
		//
		// min(gx*sx, gy*sy, gz*sz) > gx*|dx| + gy*|dy| + gz*sz
		//
		// One of the summands on the RHS is an argument of the min on the LHS,
		// and thus the inequality is clearly false since the summands are all
		// positive.
		//
		// With all three less, we can't sensibly simplify this any further:
		//
		// min(gx*sx, gy*sy, gz*sz) > gx*|dx| + gy*|dy| + gz*|dz|
		//
		// So let's start by checking that.
		// }}}
		ucell sumPairs1 = 0;
		ucell minPairs2 = ucell.max;

		// Need to have a default here for the case when everything overflows
		ubyte axis2 = 0;

		for (ubyte i = 0; i < dim; ++i) {
			if (!delta.v[i])
				continue;

			ubyte p = gcdLog(cast(ucell)delta.v[i]);
			ucell g = cast(ucell)1 << p;
			ucell s = end.v[i] - beg.v[i] + 1;
			ucell d = abs(delta.v[i]);

			// The multiplications can overflow: we can check for that quickly
			// since we have the gcdLog:
			//
			// g * x <= ucell.max
			//     x <= ucell.max / g
			//     x <= 2^(ucell bits - p)
			//
			// But if p is zero, we get 2^(ucell bits) which is ucell.max + 1 and
			// therefore overflows to 0. When p is zero, g is 1, so use ucell.max
			// in that case.
			auto mulMax = p ? cast(ucell)1 << ucell.sizeof*8 - p : ucell.max;

			if (s <= mulMax) {
				auto gs = g * s;
				if (gs < minPairs2) {
					minPairs2 = gs;
					axis2 = i;
				}
			} else {
				// If g*s overflows, the minimum doesn't grow, so just ignore that
				// case.
			}

			if (d <= mulMax) {
				// The d*s multiplication doesn't overflow, but adding the product
				// to sumPairs1 still might.
				auto ds = d * s;
				if (sumPairs1 <= ucell.max - ds)
					sumPairs1 += ds;
				else {
					// sumPairs1 is bigger than an ucell can hold: either minPairs2
					// is less or they're both really huge. If minPairs2 is less, we
					// know what to do. If they're both huge, we make the reasonable
					// assumption that no matter what we do, it's still going to
					// take a really long time, so just pick one arbitrarily.
					goto method2;
				}
			} else {
				// As above: sumPairs1 exceeds the size of an ucell.
				goto method2;
			}
		}

		// The move count can plausibly be ucell.max so we can't use an
		// initial setting like that for the maximum: we need an auxiliary
		// boolean.
		ucell bestMoves = void;
		bool gotMoves = false;

		// Now we know which method is cheaper, so pick the better one and get
		// working. If they're equal, we can pick either: method 2 seems
		// computationally a bit cheaper in that case (no, I haven't measured
		// it), so do that for the equal case.
		if (sumPairs1 < minPairs2) {
			// Method 1: check a few points along each edge.

			// For each axis...
			for (ucell i = 0; i < dim; ++i) {
				// ... with a nonzero delta...
				if (!delta.v[i])
					continue;

				// ... consider the 1D ray along the axis, and figure out the
				// coordinate range in the box that it can plausibly hit.
				cell a, b;
				getBegEnd(beg.v[i], end.v[i], o.v[i], delta.v[i], a, b);

				// For each point that we might hit...
				for (cell p = a; p <= b; ++p) {
					// ... figure out the move counts that hit it which would also
					// be improvements to bestMoves.
					ucell moves, increment;
					auto n = getMoves(
						o.v[i], p, delta.v[i],
						moves, increment, gotMoves ? &bestMoves : null);

					// For each of the plausible move counts, in order...
					nextMoveCount: for (ucell c = 0; c < n; ++c) {
						auto m = moves + c*increment;

						// ... make sure that along the other axes, with the same
						// number of moves, we fall within the box.
						for (ucell j = 0; j < dim; ++j) if (i != j)
							if (!matches(m, beg.v[j], end.v[j], o.v[j], delta.v[j]))
								continue nextMoveCount;

						// If we did, we have a better solution for the whole ray,
						// and we can move to the next point. (Since getMoves()
						// guarantees that any later m's for this point would be
						// greater.)
						bestMoves = m;
						gotMoves  = true;
						break;
					}
				}
			}
		} else {
	method2:
			// Method 2: check all points along a selected axis. Practically
			// identical to the point-loop in method 1: won't be repeating the
			// comments here.

			// If we aborted method selection early, our selected axis might have
			// a zero delta: rectify that.
			if (!delta.v[axis2]) {
				assert (axis2 == 0);
				do ++axis2; while (!delta.v[axis2]);
			}

			for (cell p = beg.v[axis2]; p <= end.v[axis2]; ++p) {
				ucell moves, increment;
				auto n = getMoves(o.v[axis2], p, delta.v[axis2],
				                  moves, increment, gotMoves ? &bestMoves : null);

				nextMoveCount2: for (ucell c = 0; c < n; ++c) {
					auto m = moves + c*increment;

					for (ucell j = 0; j < dim; ++j) if (axis2 != j)
						if (!matches(m, beg.v[j], end.v[j], o.v[j], delta.v[j]))
							continue nextMoveCount2;

					bestMoves = m;
					gotMoves  = true;
					break;
				}
			}
		}
		if (!gotMoves)
			return false;

		moveCnt = bestMoves;
		at.v[] = o.v[] + bestMoves * delta.v[];
		return true;
	}

	.Coords!(dim) getEndOfContiguousRange(
		    .Coords!(dim) endPt,
		ref .Coords!(dim) from,
		    .Coords!(dim) to,
		    .Coords!(dim) origBeg,
		out bool reachedTo,
		    .Coords!(dim) tessellBeg,
		    .Coords!(dim) areaBeg)
	{
		static if (dim >= 2)
			// Copy, don't slice!
			cell[dim-1] initFromV = from.v[1..$];

		for (ubyte i = 0; i < dim-1; ++i) {
			if (endPt.v[i] == to.v[i]) {
				// Hit the end point exactly: we'll be going to the next line/page
				// on this axis
				from.v[i] = origBeg.v[i];
			} else {
				// Did not reach the end point or the box is too big to go any
				// further as a contiguous block. The remaining axes won't be
				// changing.
				endPt.v[i+1..$] = from.v[i+1..$];

				if (endPt.v[i] < to.v[i] || from.v[i] > to.v[i]) {
					// Did not reach the endpoint: either ordinarily or because "to"
					// is wrapped around with respect to "from", so it's not
					// possible to reach the endpoint from "from" without going to
					// another box.
					//
					// The next point will be one up on this axis.
					from.v[i] = endPt.v[i] + 1;
				} else {
					// Reached "to" on this axis, but the box is too big to go any
					// further.
					endPt.v[i] = to.v[i];

					// If we're at "to" on the other axes as well, we're there.
					if (endPt.v[i+1..$] == to.v[i+1..$])
						reachedTo = true;
					else {
						// We should go further on the next axis next time around,
						// since we're done along this one.
						from.v[i] = origBeg.v[i];
						++from.v[i+1];
					}
				}
				goto end;
			}
		}
		// All the coords but the last were the same: check the last one too.
		if (endPt.v[$-1] == to.v[$-1])
			reachedTo = true;
		else {
			if (endPt.v[$-1] < to.v[$-1] || from.v[$-1] > to.v[$-1])
				from.v[$-1] = endPt.v[$-1] + 1;
			else {
				endPt.v[$-1] = to.v[$-1];
				reachedTo = true;
			}
		}
end:
		static if (dim >= 2) for (ubyte i = 0; i < dim-1; ++i) {
			// If we were going to cross a line/page but we're actually in a box
			// tessellated in such a way that we can't, wibble things so that we
			// just go to the end of the line/page.
			if (endPt.v[i+1] > initFromV[i] && tessellBeg.v[i] != areaBeg.v[i]) {
				endPt.v[i+1..$] = initFromV[i..$];
				from .v[i+1]    = initFromV[i] + 1;
				from .v[i+2..$] = initFromV[i+1..$];
				reachedTo = false;
				break;
			}
		}
		return endPt;
	}
}

// Non-dimension-specific utils

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
