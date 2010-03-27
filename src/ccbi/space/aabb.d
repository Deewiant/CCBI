// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2009-09-20 12:02:44

module ccbi.space.aabb;

import tango.math.Math   : min, max;
import tango.stdc.string : memmove;

import ccbi.stdlib : abs, gcdLog;
import ccbi.space.coords;
import ccbi.space.utils;

package:

// Various *NoOffset functions exist; their argument Coords is one which is
// relative to beg, not (0,0,0).
//
// If a non-NoOffset version exists, the NoOffset one is typically faster.
struct AABB(cell dim) {
	static assert (dim >= 1 && dim <= 3);

	alias .Coords   !(dim) Coords;
	alias .Dimension!(dim).Coords InitCoords;
	alias .Dimension!(dim).contains contains;

	cell* data;
	size_t size;
	Coords beg, end;

	static if (dim >= 2) size_t width;
	static if (dim >= 3) size_t area;

	static typeof(*this) opCall(Coords b, Coords e)
	in {
		foreach (i, x; b.v)
			assert (x <= e.v[i]);
	} body {
		auto aabb = unsafe(b, e);
		aabb.finalize;
		return aabb;
	}
	static typeof(*this) unsafe(Coords b, Coords e) {
		AABB aabb;
		with (aabb) {
			beg = b;
			end = e;
		}
		return aabb;
	}
	void finalize() {
		size = end.x - beg.x + 1;

		static if (dim >= 2) {
			width = size;
			size *= end.y - beg.y + 1;
		}
		static if (dim >= 3) {
			area = size;
			size *= end.z - beg.z + 1;
		}
	}

	void alloc() {
		data = cmalloc(size);
		data[0..size] = ' ';
	}

	int opEquals(AABB b) { return beg == b.beg && end == b.end; }

	bool contains(Coords p) { return contains(p, beg, end); }
	bool contains(AABB b)
	out(result) {
		assert (!result || this.overlaps(b));
	} body {
		return contains(b.beg) && contains(b.end);
	}

	cell opIndex(Coords p)
	in {
		assert (this.contains(p));

		// If alloc hasn't been called, might not be caught
		assert (data !is null);
		assert (getIdx(p) < size);
	} body {
		return data[getIdx(p)];
	}
	void opIndexAssign(cell val, Coords p)
	in {
		assert (this.contains(p));

		// Ditto above
		assert (data !is null);
		assert (getIdx(p) < size);
	} body {
		data[getIdx(p)] = val;
	}
	size_t getIdx        (Coords p) { return getIdxNoOffset(p - beg); }
	size_t getIdxNoOffset(Coords p) {
		size_t idx = p.x;

		static if (dim >= 2) idx += width * p.y;
		static if (dim >= 3) idx += area  * p.z;

		return idx;
	}

	cell getNoOffset(Coords p)
	in {
		assert (data !is null);
		assert (getIdxNoOffset(p) < size);
	} body {
		return data[getIdxNoOffset(p)];
	}
	cell setNoOffset(Coords p, cell val)
	in {
		assert (data !is null);
		assert (getIdxNoOffset(p) < size);
	} body {
		return data[getIdxNoOffset(p)] = val;
	}

	bool rayIntersects(Coords o, Coords delta, out ucell moveCnt, out Coords at)
	in {
		// It should be a ray and not a point
		assert (delta != 0);
	} out (intersects) {
		assert (!intersects || this.contains(at));
	} body {
		// {{{ Helpers
		static bool matches(ucell moves, cell e1, cell e2, cell from, cell delta)
		{
			if (!delta) {
				// We check that the zero deltas are correct in advance
				return true;
			}
			cell pos = from + cast(cell)moves * delta;
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
				end = min(beg + delta + cast(cell)1, edge2);
			} else {
				end = edge2;
				beg = max(end + delta - cast(cell)1, edge1);
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

			auto p = gcdLog(cast(ucell)delta.v[i]);
			auto g = cast(ucell)1 << p;
			auto s = cast(ucell)(this.end.v[i] - this.beg.v[i] + 1);
			auto d = cast(ucell)abs(delta.v[i]);

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
			auto mulMax = p ? 1 << ucell.sizeof*8 - p : ucell.max;

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
		at.v[] = o.v[] + cast(cell)bestMoves * delta.v[];
		return true;
	}

	bool overlaps(AABB b) {
		for (size_t i = 0; i < dim; ++i)
			if (!(beg.v[i] <= b.end.v[i] && b.beg.v[i] <= end.v[i]))
				return false;
		return true;
	}
	bool getOverlapWith(AABB box, ref AABB overlap)
	out (result) {
		if (result) {
			assert (this.overlaps(box));
			assert (this.contains(overlap));
			assert ( box.contains(overlap));
		} else
			assert (!this.overlaps(box));
	} body {
		if (this.overlaps(box)) {
			auto ob = beg; ob.maxWith(box.beg);
			auto oe = end; oe.minWith(box.end);

			overlap = AABB(ob, oe);
			return true;
		} else
			return false;
	}

	// True if we can create a new AABB which covers exactly this and the
	// argument: no more, no less
	bool canFuseWith(AABB b)
	out (result) {
		if (result) {
			static if (dim > 1)
				assert (this.onSameAxisAs(b));
		}
	} body {
		static if (dim == 1)
			return end.x+1 == b.beg.x || beg.x == b.end.x+1 || overlaps(b);
		else static if (dim == 2) {
			bool overlap = false;
			if (
				beg.x == b.beg.x && end.x == b.end.x &&
				(end.y+1 == b.beg.y || beg.y == b.end.y+1
				 || overlap || (overlap = overlaps(b),overlap))
			)
				return true;

			if (
				beg.y == b.beg.y && end.y == b.end.y &&
				(end.x+1 == b.beg.x || beg.x == b.end.x+1
				 || overlap || (overlap = overlaps(b),overlap))
			)
				return true;
		} else static if (dim == 3) {
			bool overlap = false;
			if (
				beg.x == b.beg.x && end.x == b.end.x &&
				beg.z == b.beg.z && end.z == b.end.z &&
				(end.y+1 == b.beg.y || beg.y == b.end.y+1
				 || overlap || (overlap = overlaps(b),overlap))
			)
				return true;

			if (
				beg.y == b.beg.y && end.y == b.end.y &&
				beg.z == b.beg.z && end.z == b.end.z &&
				(end.x+1 == b.beg.x || beg.x == b.end.x+1
				 || overlap || (overlap = overlaps(b),overlap))
			)
				return true;

			if (
				beg.x == b.beg.x && end.x == b.end.x &&
				beg.y == b.beg.y && end.y == b.end.y &&
				(end.z+1 == b.beg.z || beg.z == b.end.z+1
				 || overlap || (overlap = overlaps(b),overlap))
			)
				return true;
		}

		return false;
	}

	static if (dim > 1) {

	bool onSameAxisAs(AABB b) {
		if (
			(beg.x == b.beg.x && end.x == b.end.x) ||
			(beg.y == b.beg.y && end.y == b.end.y)
		)
			return true;

		static if (dim >= 3)
			return onSamePrimaryAxisAs(b);

		return false;
	}
	bool onSamePrimaryAxisAs(AABB b) {
		static if (dim == 2) return beg.y == b.beg.y && end.y == b.end.y;
		static if (dim == 3) return beg.z == b.beg.z && end.z == b.end.z;
	}

	}

	bool canDirectCopy(AABB box, size_t size) {
		static if (dim == 1) return true;
		else {
			if (size <= this.width && size == box.width) return true;
			static if (dim == 2) return width == box.width;
			static if (dim == 3) return width == box.width && area == box.area;
		}
	}
	bool canDirectCopy(AABB box, AABB owner, size_t size) {
		static if (dim == 2) if (box.width != owner.width) return false;
		static if (dim == 3) if (box.area  != owner.area)  return false;
		return canDirectCopy(box, size);
	}

	// This should be unallocated, the other allocated. Can't be checked in the
	// contract due to the union.
	//
	// Takes ownership of old's array: it must be contained within this.
	void consume(AABB old)
	in {
		assert (this.contains(old));
	} body {
		auto oldLength = old.size;

		data = crealloc(old.data, size);
		data[oldLength..size] = ' ';

		auto oldIdx = this.getIdx(old.beg);

		if (canDirectCopy(old, oldLength)) {
			if (oldIdx != 0) {
				if (oldIdx < oldLength) {
					memmove(&data[oldIdx], data, oldLength * cell.sizeof);
					data[0..oldIdx] = ' ';
				} else {
					data[oldIdx..oldIdx + oldLength] = data[0..oldLength];
					data[0..oldLength] = ' ';
				}
			}

		} else static if (dim == 2) {

			auto iend = oldIdx + (beg == old.beg ? old.width : 0);
			auto oldEnd = oldIdx + oldLength / old.width * width;

			for (auto i = oldEnd, j = oldLength; i > iend;) {
				i -= this.width;
				j -=  old.width;

				// The original data is always earlier in the array than the
				// target, so overlapping can only occur from one direction:
				// i+old.width <= j can't happen
				assert (i+old.width > j);

				if (j+old.width <= i) {
					data[i..i+old.width] = data[j..j+old.width];
					data[j..j+old.width] = ' ';

				} else if (i != j) {
					memmove(&data[i], &data[j], old.width * cell.sizeof);
					data[j..i] = ' ';
				}
			}
		} else static if (dim == 3) {

			auto sameBeg = beg == old.beg;
			auto iend = oldIdx + (sameBeg && width == old.width ? old.area : 0);
			auto oldEnd = oldIdx + oldLength / old.area * area;

			for (auto i = oldEnd, j = oldLength; i > iend;) {
				i -= this.area;

				auto kend = i + (sameBeg ? old.width : 0);

				for (auto k = i + old.area/old.width*width, l = j; k > kend;) {
					k -= this.width;
					l -=  old.width;

					assert (k+old.width > l);

					if (l+old.width <= k) {
						data[k..k+old.width] = data[l..l+old.width];
						data[l..l+old.width] = ' ';
					} else if (k != l) {
						memmove(&data[k], &data[l], old.width * cell.sizeof);
						data[l..k] = ' ';
					}
				}
				j -= old.area;
			}
		}
	}

	// This and old should both be allocated; copies old into this at the
	// correct position.
	//
	// Doesn't allocate anything: this should contain old.
	void subsume(AABB old)
	in {
		assert (this.contains(old));
	} body {
		subsumeArea(old, old, old.data[0..old.size]);
	}

	// This and b should be allocated, area not; copies the cells in the area
	// from b to this.
	//
	// Doesn't allocate anything: both this and b should contain area.
	void subsumeArea(AABB b, AABB area)
	in {
		assert (this.contains(area));
		assert (b.contains(area));
	} out {
		assert ((*this)[area.beg] == b[area.beg]);
		assert ((*this)[area.end] == b[area.end]);
	} body {
		subsumeArea(b, area, b.data[b.getIdx(area.beg)..b.getIdx(area.end)+1]);
	}

	// Internal: copies from the given array to this, given that it's an area
	// contained in owner.
	//
	// We can't just use only area since the data is usually not continuous:
	//
	//   ownerowner
	//   ownerAREAr
	//   ownerAREAr
	//   ownerAREAr
	//
	//   ownerowner
	//   ownerDATAD
	//   ATADATADAT
	//   ADATADATAr
	//
	// In the above, if we advanced by area.width instead of owner.width we'd be
	// screwed.
	private void subsumeArea(AABB owner, AABB area, cell[] data)
	in {
		assert ( this.contains(area));
		assert (owner.contains(area));
	} out {
		assert ((*this)[area.beg] == data[0]  );
		assert ((*this)[area.end] == data[$-1]);
		assert ((*this)[area.beg] == owner[area.beg]);
		assert ((*this)[area.end] == owner[area.end]);
	} body {
		auto begIdx = getIdx(area.beg);

		if (canDirectCopy(area, owner, area.size))
			this.data[begIdx .. begIdx + data.length] = data;

		else static if (dim == 2) {
			for (size_t i = 0, j = begIdx; i < data.length;) {
				this.data[j..j+area.width] = data[i..i+area.width];
				i += owner.width;
				j +=  this.width;
			}

		} else static if (dim == 3) {
			for (size_t i = 0, j = begIdx; i < data.length;) {
				auto areaHeight = area.area / area.width;

				for (size_t k = i, l = j; k < i + areaHeight * owner.width;) {
					this.data[l..l+area.width] = data[k..k+area.width];
					k += owner.width;
					l +=  this.width;
				}
				i += owner.area;
				j +=  this.area;
			}
		}
	}

	void blankArea(AABB area)
	in {
		assert (this.contains(area));
	} out {
		assert ((*this)[area.beg] == ' ');
		assert ((*this)[area.end] == ' ');
	} body {
		auto begIdx = getIdx(area.beg);

		if (canDirectCopy(area, area.size))
			this.data[begIdx .. begIdx + area.size] = ' ';

		else static if (dim == 2) {

			auto areaHeight = area.size / area.width;
			auto iEnd       = begIdx + areaHeight * this.width;
			for (size_t i = begIdx; i < iEnd; i += this.width)
				this.data[i .. i + area.width] = ' ';

		} else static if (dim == 3) {

			auto areaDepth  = area.size / area.area;
			auto areaHeight = area.area / area.width;
			auto iEnd       = begIdx + areaDepth * this.area;
			auto jEndAdd    = areaHeight * this.width;

			for (size_t i = begIdx; i < iEnd; i += this.area)
				for (size_t j = i; j < i + jEndAdd; j += this.width)
					this.data[j .. j + area.width] = ' ';
		}
	}

	cell[] getContiguousRange(
		ref Coords from, Coords to, Coords origBeg, ref bool reachedTo)
	in {
		assert (this.contains(from));
		foreach (i, x; from.v)
			assert (x <= to.v[i]);
	} out {
		foreach (i, x; from.v) {
			if (!reachedTo)
				assert (x <= to.v[i]);
			assert (x >= origBeg.v[i]);
		}
	} body {
		auto fromIdx = getIdx(from);

		auto endPt = this.end;

		for (ubyte i = 0; i < dim-1; ++i) {
			if (endPt.v[i] == to.v[i])
				from.v[i] = origBeg.v[i];
			else {
				endPt.v[i+1..$] = from.v[i+1..$];

				if (endPt.v[i] < to.v[i])
					from.v[i] = endPt.v[i] + cast(cell)1;
				else {
					endPt.v[i] = to.v[i];

					if (endPt.v[i+1..$] == to.v[i+1..$])
						reachedTo = true;
					else {
						from.v[i] = origBeg.v[i];
						++from.v[i+1];
					}
				}

				goto end;
			}
		}
		// All the coords but the last were the same: check the last one too
		if (endPt.v[$-1] == to.v[$-1])
			reachedTo = true;
		else {
			if (endPt.v[$-1] < to.v[$-1])
				from.v[$-1] = endPt.v[$-1] + cast(cell)1;
			else {
				endPt.v[$-1] = to.v[$-1];
				from.v[$-1] = origBeg.v[$-1];
			}
		}

end:
		return data[fromIdx .. getIdx(endPt)+1];
	}
}

// Modifies the given beg/end pair to give a box which contains the given
// coordinates and overlaps with none of the given boxes. The coordinates
// should, of course, be already contained between the beg and end.
void tessellateAt(cell dim)(
	Coords!(dim) p, AABB!(dim)[] bs, ref Coords!(dim) beg, ref Coords!(dim) end)
in {
	assert (AABB!(dim).unsafe(beg,end).contains(p));
} out {
	foreach (b; bs)
		assert (!AABB!(dim).unsafe(beg,end).overlaps(b));
} body {
	foreach (b; bs) foreach (i, x; p.v) {
		// This could be improved, consider for instance the bottommost box in
		// the following graphic and its current tessellation:
		//
		// +-------+    +--*--*-+
		// |       |    |X .  . |
		// |       |    |  .  . |
		// |     +---   *..*..+---
		// |     |      |  .  |
		// |  +--|      *..+--|
		// |  |  |      |  |  |
		// |  |  |      |  |  |
		// +--|  |      +--|  |
		//
		// (Note that this isn't actually a tessellation: all points will get
		// a rectangle containing the rectangle at X.)
		//
		// Any of the following three would be an improvement (and they would
		// actually be tessellations):
		//
		// +--*--*-+    +-------+    +-----*-+
		// |  .  . |    |       |    |     . |
		// |  .  . |    |       |    |     . |
		// |  .  +---   *.....+---   |     +---
		// |  .  |      |     |      |     |
		// |  +--|      *..+--|      *..+--|
		// |  |  |      |  |  |      |  |  |
		// |  |  |      |  |  |      |  |  |
		// +--|  |      +--|  |      +--|  |
		const cell l = 1;
		if (b.end.v[i] < x) beg.v[i] = max(  beg.v[i], b.end.v[i]+l);
		if (b.beg.v[i] > x) end.v[i] = min(b.beg.v[i]-l, end.v[i]);
	}
}
