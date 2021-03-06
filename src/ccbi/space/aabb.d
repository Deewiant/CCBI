// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2009-09-20 12:02:44

module ccbi.space.aabb;

import tango.math.Math   : min, max;
import tango.stdc.string : memmove;

import ccbi.stdlib : clampedAdd, clampedMul, gcdLog;
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

	size_t clampedSize() {
		size_t sz = 1;
		for (ucell i = 0; i < dim; ++i)
			sz = clampedMul(
				sz, clampedAdd(cast(size_t)(end.v[i] - beg.v[i]), cast(size_t)1));
		return sz;
	}

	size_t volumeOn(ubyte axis) {
		assert (axis < dim);
		static if (dim >= 2) if (axis == 1) return width;
		static if (dim >= 3) if (axis == 2) return area;
		return 1;
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

	// Works even if this is an unsafe box with beg > end.
	bool safeContains(Coords p) {
		for (ucell i = 0; i < dim; ++i) {
			if (beg.v[i] > end.v[i]) {
				if (!(p.v[i] >= beg.v[i] || p.v[i] <= end.v[i]))
					return false;
			} else
				if (!(p.v[i] >= beg.v[i] && p.v[i] <= end.v[i]))
					return false;
		}
		return true;
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
		// Can't assert contains(p + beg) since NoOffset usage typically means
		// that our beg/end don't match data.

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
	out (yes) {
		if (yes)
			static if (dim > 1)
				assert (this.onSameAxisAs(b));
	} body {
		bool overlap = this.overlaps(b);
		outer:
		for (cell i = 0; i < dim; ++i) {
			for (cell j = 0; j < dim; ++j)
				if (i != j && !(beg.v[j] == b.beg.v[j] && end.v[j] == b.end.v[j]))
						continue outer;

			if (clampedAdd!(cell)(end.v[i], 1) == b.beg.v[i]
			 || clampedAdd!(cell)(b.end.v[i], 1) == beg.v[i]
			 || overlap)
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
}

// Modifies the given beg/end pair to give a box which contains the given
// coordinates but doesn't overlap with any of the given boxes. The coordinates
// should, of course, be already contained between the beg and end.
void tessellateAt(cell dim)(
	Coords!(dim) p, AABB!(dim)[] bs, ref Coords!(dim) beg, ref Coords!(dim) end)
in {
	assert (Dimension!(dim).contains(p, beg, end));
} out {
	foreach (b; bs)
		assert (!AABB!(dim).unsafe(beg, end).overlaps(b));
} body {
	foreach (b; bs)
		tessellateAt(p, b.beg, b.end, beg, end);
}

// Since the algorithm is currently just a fold over the boxes, this simpler
// version exists to avoid heap allocation.
void tessellateAt(cell dim)(
	Coords!(dim) p, Coords!(dim) avoidBeg, Coords!(dim) avoidEnd,
	ref Coords!(dim) beg, ref Coords!(dim) end)
in {
	assert (Dimension!(dim).contains(p, beg, end));
} out {
	assert (!AABB!(dim).unsafe(beg, end).overlaps(
		AABB!(dim).unsafe(avoidBeg, avoidEnd)));
} body {
	foreach (i, x; p.v) {
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
		if (avoidEnd.v[i] < x) beg.v[i] = max(     beg.v[i], avoidEnd.v[i]+1);
		if (avoidBeg.v[i] > x) end.v[i] = min(avoidBeg.v[i]-1,    end.v[i]);
	}
}
