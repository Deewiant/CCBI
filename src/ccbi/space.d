// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2006-06-09 17:34:29

// Funge-Space and the Coords struct.
module ccbi.space;

import tango.io.device.Array      : Array;
import tango.io.model.IConduit    : OutputStream;
import tango.io.stream.Typed      : TypedOutput;
import tango.math.Math            : min, max;
import tango.stdc.stdlib          : malloc, realloc, free;
import tango.stdc.string          : memmove;
import tango.text.convert.Integer : format;

public import ccbi.cell;
       import ccbi.templateutils;
       import ccbi.stats;
       import ccbi.stdlib;
       import ccbi.utils;

struct Coords(cell dim) {
	static assert (dim >= 1 && dim <= 3);

	union {
		align (1) struct {
			                       cell x;
			static if (dim >= 2) { cell y; }
			static if (dim >= 3) { cell z; }
		}
		cell[dim] v;
	}

	char[] toString() {
		char[ToString!(cell.min).length] buf = void;

		char[] s = "(";
		                                 s ~= format(buf, x);
		foreach (x; v[1..$]) { s ~= ','; s ~= format(buf, x); }
		s ~= ')';
		return s;
	}

	Coords!(3) extend(cell val) {
		Coords!(3) c;
		c.v[0..dim] = v;
		c.v[dim..$] = val;
		return c;
	}

	int opEquals(cell c) {
		foreach (x; v)
			if (x != c)
				return false;
		return true;
	}
	int opEquals(Coords c) { return v == c.v; }

	void maxWith(Coords c) { foreach (i, ref x; v) if (c.v[i] > x) x = c.v[i]; }
	void minWith(Coords c) { foreach (i, ref x; v) if (c.v[i] < x) x = c.v[i]; }

	template Ops(T...) {
		static assert (T.length != 1);

		static if (T.length == 0)
			const Ops = "";
		else
			const Ops =
				"Coords op" ~T[0]~ "(cell c) {
					Coords co = *this;
					co.v[] "~T[1]~"= c;
					return co;
				}
				void op" ~T[0]~ "Assign(cell c) {
					v[] "~T[1]~"= c;
				}

				Coords op" ~T[0]~ "(Coords c) {
					Coords co = *this;
					co.v[] "~T[1]~"= c.v[];
					return co;
				}
				void op" ~T[0]~ "Assign(Coords c) {
					v[] "~T[1]~"= c.v[];
				}"
				~ Ops!(T[2..$]);
	}

	mixin (Ops!(
		"Mul", "*",
		"Add", "+",
		"Sub", "-"
	));
}

template Dimension(cell dim) {
	template Coords(cell x, cell y, cell z) {
		     static if (dim == 1) const Coords = .Coords!(dim)(x);
		else static if (dim == 2) const Coords = .Coords!(dim)(x,y);
		else static if (dim == 3) const Coords = .Coords!(dim)(x,y,z);
	}
	template Coords(cell x, cell y) { const Coords = Coords!(x,y,0); }
	template Coords(cell x)         { const Coords = Coords!(x,0,0); }

	bool contains(.Coords!(dim) pos, .Coords!(dim) beg, .Coords!(dim) end) {
		foreach (i, x; pos.v)
			if (!(x >= beg.v[i] && x <= end.v[i]))
				return false;
		return true;
	}
}

// We use these for AABB data mainly to keep memory usage in check. Using
// cell[] data, "data.length = foo" appears to keep the original data unfreed
// if a reallocation occurred until at least the next GC. I'm not sure if that
// was the exact cause, but using this instead of the GC can reduce worst-case
// memory usage by up to 50% in some cases. We weren't really utilizing the
// advantages of the GC anyway.
private cell* cmalloc(size_t s) {
	return cast(cell*)malloc(s * cell.sizeof);
}
private cell* crealloc(cell* p, size_t s) {
	return cast(cell*)realloc(p, s * cell.sizeof);
}

// Various *NoOffset functions exist; their argument Coords is one which is
// relative to beg, not (0,0,0).
//
// If a non-NoOffset version exists, the NoOffset one is typically faster.
private struct AABB(cell dim) {
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
	cell opIndexAssign(cell val, Coords p)
	in {
		assert (this.contains(p));

		// Ditto above
		assert (data !is null);
		assert (getIdx(p) < size);
	} body {
		return data[getIdx(p)] = val;
	}
	private size_t getIdx        (Coords p) { return getIdxNoOffset(p - beg); }
	private size_t getIdxNoOffset(Coords p) {
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

	bool rayIntersects(Coords from, Coords dir, out ucell steps, out Coords at)
	in {
		// It should be a ray and not a point
		assert (dir != 0);
	} out (intersects) {
		assert (!intersects || this.contains(at));
	} body {
		// The range of possible coordinates in the given range that the given 1D
		// ray can collide with.
		static void getBegEnd(
			cell edge1, cell edge2, cell from, cell delta,
			out cell beg, out cell end)
		{
			if (delta > 0) {
				beg = edge1;
				if (from >= edge1 && from <= edge2)
					beg = from + cast(cell)1;

				end = min(beg + delta - cast(cell)1, edge2);

			} else {
				end = edge2;
				if (from >= edge1 && from <= edge2)
					end = from - cast(cell)1;

				beg = max(end + delta - cast(cell)1, edge1);
			}
		}
		static bool getMoves(
			cell from, cell to, cell delta, out ucell_base moves)
		{
			// Optimization: this is the typical case
			if (delta == 1) {
				moves = cast(ucell_base)(to - from);
				return true;
			}
			return modDiv(
				cast(ucell_base)(to - from),
				cast(ucell_base)delta,
				moves);
		}
		static bool matches(ucell moves, cell e1, cell e2, cell from, cell delta)
		{
			cell pos = from + cast(cell)moves * delta;
			return pos >= e1 && pos <= e2;
		}

		ucell bestMoves = void;
		bool gotMoves = false;

		for (size_t i = 0; i < dim; ++i) {
			if (!dir.v[i]) {
				// We never move along this axis: make sure we're contained in the
				// box.
				if (!(from.v[i] >= this.beg.v[i] && from.v[i] <= this.end.v[i]))
					return false;
				continue;
			}

			// Figure out the coordinates in the box that this 1D ray can
			// plausibly hit.
			cell rangeBeg, rangeEnd;
			getBegEnd(
				this.beg.v[i], this.end.v[i],
				from.v[i], dir.v[i], rangeBeg, rangeEnd);

			// For each coordinate...
			matchCoords: for (cell c = rangeBeg; c <= rangeEnd; ++c) {

				// ... figure out the number of moves needed to reach that
				// coordinate...
				ucell moves;
				if (!getMoves(from.v[i], c, dir.v[i], moves))
					continue;

				// Grab only the lowest.
				//
				// If we gotMoves then bestMoves definitely works. The bestMoves
				// that we want is the minimal moves, the one that first hits the
				// box, so don't bother with anything longer whether it would
				// intersect or not.
				if (gotMoves && moves >= bestMoves)
					continue;

				// ... and make sure that the other axes also need the same number
				// of moves.
				for (auto j = 0; j < dim; ++j)
					if (i != j && dir.v[j]
					 && !matches(
					 	moves, this.beg.v[j], this.end.v[j], from.v[j], dir.v[j])
					)
						continue matchCoords;

				bestMoves = moves;
				gotMoves  = true;
			}
		}

		if (gotMoves) {
			steps = bestMoves;
			at.v[] = from.v[] + cast(cell)bestMoves * dir.v[];
			return true;
		} else
			return false;
	}

	bool overlaps(AABB b) {
		for (size_t i = 0; i < dim; ++i)
			if (!(beg.v[i] <= b.end.v[i] && b.beg.v[i] <= end.v[i]))
				return false;
		return true;
	}
	bool getOverlapWith(AABB box, ref AABB overlap)
	in {
		// Allows us to make some assumptions
		assert (!this.contains(box));
		assert (!box.contains(*this));
	} out (result) {
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
	void subsumeArea(AABB owner, AABB area, cell[] data)
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

	// Gives an AABB from within this box which contains the given coordinates
	// and overlaps with none of the given boxes.
	//
	// The AABB returned by this function is only a view: it shares its data
	// with this AABB. Be careful! Only contains and the *NoOffset functions in
	// it work properly, since the others (notably, getIdx and thereby
	// opIndex[Assign]) tend to depend on beg and end matching data.
	//
	// In addition, it is weird: its width and height are not its own, so that
	// its getNoOffsets work.
	AABB tessellationAt(Coords p, AABB[] bs)
	in {
		assert (this.contains(p));
	} out (tes) {
		foreach (b; bs)
			assert (!tes.overlaps(b));
	} body {
		auto tes = *this;
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
			if (b.end.v[i] < x) tes.beg.v[i] = max(tes.beg.v[i], b.end.v[i]+l);
			if (b.beg.v[i] > x) tes.end.v[i] = min(b.beg.v[i]-l, tes.end.v[i]);
		}
		return tes;
	}

	// These return false if the skipping couldn't be completed within this box.
	bool skipSpacesNoOffset(ref Coords p, Coords delta, Coords ob2b, Coords ob2e)
	in {
		assert (contains(p, ob2b, ob2e));
	} out (done) {
		assert (done == (contains(p, ob2b, ob2e) && getNoOffset(p) != ' '));
	} body {
		while (getNoOffset(p) == ' ') {
			p += delta;
			if (!contains(p, ob2b, ob2e))
				return false;
		}
		return true;
	}

	// The bool argument should start at false and thereafter just be passed
	// back unmodified.
	bool skipSemicolonsNoOffset(
		ref Coords p, Coords delta, Coords ob2b, Coords ob2e, ref bool inMiddle)
	in {
		assert (contains(p, ob2b, ob2e));
	} out (done) {
		assert (done == (contains(p, ob2b, ob2e) && getNoOffset(p) != ' '));
	} body {
		if (inMiddle)
			goto continuePrev;

		while (getNoOffset(p) == ';') {
			do {
				p += delta;
				if (!contains(p, ob2b, ob2e)) {
					inMiddle = true;
					return false;
				}
continuePrev:;
			} while (getNoOffset(p) != ';')

			p += delta;
			if (!contains(p, ob2b, ob2e)) {
				inMiddle = false;
				return false;
			}
		}
		return true;
	}

	bool nonSpaceAlong(size_t start, size_t stride) {
		return nonSpaceAlong(start, stride, size);
	}
	bool nonSpaceAlong(size_t start, size_t stride, size_t end) {
		for (size_t i = start; i < end; i += stride)
			if (data[i] != ' ')
				return true;
		return false;
	}
}

final class FungeSpace(cell dim, bool befunge93) {
	static assert (dim >= 1 && dim <= 3);
	static assert (!befunge93 || dim == 2);

	alias .AABB     !(dim)            AABB;
	alias .Coords   !(dim)            Coords;
	alias .Dimension!(dim).Coords     InitCoords;
	alias .Cursor   !(dim, befunge93) Cursor;

	// All arbitrary
	private const
		NEWBOX_PAD = 8,

		// A box 5 units wide, otherwise of size NEWBOX_PAD.
		ACCEPTABLE_WASTE = Power!(size_t, NEWBOX_PAD, dim-1) * 5,

		BIGBOX_PAD = 512,

		// Implicitly defines an ACCEPTABLE_WASTE for BIGBOXes: it's
		// (BIG_SEQ_MAX_SPACING - 1) * BIGBOX_PAD^(dim-1).
		//
		// This is a distance between two cells, not the number of spaces between
		// them, and thus should always be at least 1.
		BIG_SEQ_MAX_SPACING = 4;

	static assert (NEWBOX_PAD          >= 0);
	static assert (BIGBOX_PAD          >  NEWBOX_PAD);
	static assert (BIG_SEQ_MAX_SPACING >= 1);

	private {
		struct Memory {
			AABB box, finalBox;
			Coords c;
		}
		AnamnesicRing!(Memory, 3) recentBuf;
		bool justPlacedBig = void;
		Coords bigSequenceStart = void, firstPlacedBig = void;

		Cursor*[] cursors;
	}
	Stats* stats;

	private AABB[] boxen;

	this(Stats* stats, Array source) {
		this.stats = stats;

		load(source, null, InitCoords!(0), false);
	}

	this(FungeSpace other) {
		shallowCopy(this, other);

		// deep copy space
		boxen = other.boxen.dup;
		foreach (i, ref aabb; boxen) {
			auto orig = aabb.data;
			aabb.data = cmalloc(aabb.size);
			aabb.data[0..aabb.size] = orig[0..aabb.size];
		}

		// Empty out cursors, they refer to the other space
		cursors.length = 0;
	}

	void free() {
		foreach (box; boxen)
			.free(box.data);
		boxen.length = 0;
	}

	size_t boxCount() { return boxen.length; }

	cell opIndex(Coords c) {
		++stats.space.lookups;

		AABB box;
		if (findBox(c, box))
			return box[c];
		else
			return ' ';
	}
	cell opIndexAssign(cell v, Coords c) {
		++stats.space.assignments;

		{AABB box;
		if (findBox(c, box))
			return box[c] = v;
		}

		return placeBoxFor(c)[c] = v;
	}

	static if (befunge93) {
		Coords getBeg() { return InitCoords!( 0, 0); }
		Coords getEnd() { return InitCoords!(79,24); }
	} else {
		// FIXME: these are imprecise
		Coords getBeg() {
			auto beg = boxen[0].beg;
			foreach (box; boxen[1..$])
				foreach (i, c; box.beg.v)
					beg.v[i] = min(beg.v[i], c);
			return beg;
		}
		Coords getEnd() {
			auto end = boxen[0].end;
			foreach (box; boxen[1..$])
				foreach (i, c; box.end.v)
					end.v[i] = max(end.v[i], c);
			return end;
		}
	}

private:
	Coords jumpToBox(Coords pos, Coords delta, out AABB box, out size_t idx) {
		bool found = tryJumpToBox(pos, delta, idx);
		assert (found);
		box = boxen[idx];
		return pos;
	}
	bool tryJumpToBox(ref Coords pos, Coords delta, out size_t boxIdx)
	in {
		AABB _;
		assert (!findBox(pos, _));
	} body {
		ucell moves = 0;
		Coords pos2 = void;
		size_t idx  = void;
		foreach (i, box; boxen) {
			ucell m;
			Coords c;
			if (box.rayIntersects(pos, delta, m, c) && (m < moves || !moves)) {
				pos2  = c;
				idx   = i;
				moves = m;
			}
		}
		if (moves) {
			pos    = pos2;
			boxIdx = idx;
			return true;
		} else
			return false;
	}

	bool findHigherBox(Coords pos, ref AABB aabb, ref size_t idx) {
		foreach (i, box; boxen[0..idx]) if (box.contains(pos)) {
			idx  = i;
			aabb = box;
			return true;
		}
		return false;
	}

	bool findBox(Coords pos, out AABB box, out size_t idx) {
		idx = boxen.length;
		return findHigherBox(pos, box, idx);
	}
	bool findBox(Coords pos, out size_t idx) {
		AABB _;
		return findBox(pos, _, idx);
	}
	bool findBox(Coords pos, out AABB aabb) {
		size_t _;
		return findBox(pos, aabb, _);
	}

	AABB placeBoxFor(Coords c) {
		auto box = getBoxFor(c);
		auto pox = reallyPlaceBox(box);
		recentBuf.push(Memory(box, pox, c));
		return pox;
	}
	AABB getBoxFor(Coords c) {
		if (recentBuf.size() == recentBuf.CAPACITY) {

			Memory[recentBuf.CAPACITY] a;
			auto recents = a[0..recentBuf.read(a)];

			if (justPlacedBig) {

				auto last = recents[$-1].finalBox;

				// See if c is at bigSequenceStart except for one axis, along which
				// it's just past last.end or last.beg.
				{bool sawEnd = false, sawBeg = false;
				outer: for (cell i = 0; i < dim; ++i) {
					if (c.v[i] >  last.end.v[i] &&
					    c.v[i] <= last.end.v[i] + BIG_SEQ_MAX_SPACING)
					{
						if (sawBeg)
							break;
						sawEnd = true;

						// We can break here since we want, for any axis i, all other
						// axes to be at bigSequenceStart. Even if one of the others
						// is a candidate for this if block, the fact that the
						// current axis isn't at bigSequenceStart means that that one
						// wouldn't be correct.
						for (cell j = i + cast(cell)1; j < dim; ++j)
							if (c.v[j] != bigSequenceStart.v[j])
								break outer;

						// We're making a line/rectangle/box (depending on the value
						// of i): extend last along the axis where c was outside it.
						auto end = last.end;
						end.v[i] += BIGBOX_PAD;
						return AABB(c, end);

					// First of many places in this function where we need to check
					// the negative direction separately from the positive.
					} else if (c.v[i] <  last.beg.v[i] &&
					           c.v[i] >= last.beg.v[i] - BIG_SEQ_MAX_SPACING)
					{
						if (sawEnd)
							break;
						sawBeg = true;
						for (cell j = i + cast(cell)1; j < dim; ++j)
							if (c.v[j] != bigSequenceStart.v[j])
								break outer;

						auto beg = last.beg;
						beg.v[i] -= BIGBOX_PAD;
						return AABB(beg, c);

					} else if (c.v[i] != bigSequenceStart.v[i])
						break;
				}}

				// Match against firstPlacedBig. This is for the case when we've
				// made a few non-big boxes and then hit a new dimension for the
				// first time in a location which doesn't match with the actual
				// box. E.g.:
				//
				// BsBfBBB
				// BBBc  b
				//  n
				//
				// B being boxes, c being c, and f being firstPlacedBig. The others
				// are explained below.
				static if (dim > 1) {
					bool foundOneMatch = false;
					for (cell i = 0; i < dim; ++i) {
						if (
							(c.v[i] >  firstPlacedBig.v[i] &&
							 c.v[i] <= firstPlacedBig.v[i] + BIG_SEQ_MAX_SPACING))
						{
							// One other axis should match firstPlacedBig exactly, or
							// we'd match a point like the b in the graphic, which we
							// do not want.
							if (!foundOneMatch) {
								for (cell j = i+cast(cell)1; j < dim; ++j) {
									if (c.v[j] == firstPlacedBig.v[j]) {
										foundOneMatch = true;
										break;
									}
								}
								// We can break instead of continue, since this axis
								// wasn't equal (in here instead of the else), nor were
								// any of the previous ones (!foundOneMatch before
								// this), nor were any of the following ones
								// (!foundOneMatch after the above loop).
								if (!foundOneMatch)
									break;
							}

							auto end = last.end;
							end.v[i] += BIGBOX_PAD;

							// We want to start the resulting box from
							// bigSequenceStart (s in the graphic) instead of c, since
							// after we've finished the line on which c lies, we'll be
							// going to the point marked n next.
							//
							// If we were to make a huge box which doesn't include the
							// n column, we'd not only have to have a different
							// heuristic for the n case but we'd need to move all the
							// data in the big box to the resulting different big box
							// anyway. This way is much better.
							return AABB(bigSequenceStart, end);

						// Negative direction
						} else if (
							(c.v[i] <  firstPlacedBig.v[i] &&
							 c.v[i] >= firstPlacedBig.v[i] - BIG_SEQ_MAX_SPACING))
						{
							if (!foundOneMatch) {
								for (cell j = i+cast(cell)1; j < dim; ++j) {
									if (c.v[j] == firstPlacedBig.v[j]) {
										foundOneMatch = true;
										break;
									}
								}
								if (!foundOneMatch)
									break;
							}

							auto beg = last.beg;
							beg.v[i] -= BIGBOX_PAD;
							return AABB(beg, bigSequenceStart);

						} else if (c.v[i] == firstPlacedBig.v[i])
							foundOneMatch = true;
					}
				}

			} else {
				bool allAlongPosLine = true, allAlongNegLine = true;

				alongLoop: for (size_t i = 0; i < recents.length - 1; ++i) {
					auto v = recents[i+1].c - recents[i].c;

					for (cell d = 0; d < dim; ++d) {
						if (allAlongPosLine &&
						    v.v[d] >  NEWBOX_PAD &&
						    v.v[d] <= NEWBOX_PAD + BIG_SEQ_MAX_SPACING)
						{
							for (cell j = d + cast(cell)1; j < dim; ++j) {
								if (v.v[j] != 0) {
									allAlongPosLine = false;
									if (!allAlongNegLine)
										break alongLoop;
								}
							}

						// Negative direction
						} else if (allAlongNegLine &&
						           v.v[d] <  -NEWBOX_PAD &&
						           v.v[d] >= -NEWBOX_PAD - BIG_SEQ_MAX_SPACING)
						{
							for (cell j = d + cast(cell)1; j < dim; ++j) {
								if (v.v[j] != 0) {
									allAlongNegLine = false;
									if (!allAlongPosLine)
										break alongLoop;
								}
							}
						} else if (v.v[d] != 0) {
							allAlongPosLine = allAlongNegLine = false;
							break alongLoop;
						}
					}
				}

				if (allAlongPosLine || allAlongNegLine) {
					if (!justPlacedBig) {
						justPlacedBig = true;
						firstPlacedBig = c;
						bigSequenceStart = recents[0].c;
					}

					ubyte axis = void;
					for (ubyte i = 0; i < dim; ++i) {
							if (recents[0].box.beg.v[i] != recents[1].box.beg.v[i]) {
							axis = i;
							break;
						}
					}

					if (allAlongPosLine) {
						auto end = c;
						end.v[axis] += BIGBOX_PAD;
						return AABB(c, end);
					} else {
						assert (allAlongNegLine);
						auto beg = c;
						beg.v[axis] -= BIGBOX_PAD;
						return AABB(beg, c);
					}
				}
			}
		}
		justPlacedBig = false;
		return AABB(c - NEWBOX_PAD, c + NEWBOX_PAD);
	}

	void placeBox(AABB aabb) {
		foreach (box; boxen) if (box.contains(aabb)) {
			++stats.space.boxesIncorporated;
			return [box];
		}
		return reallyPlaceBox(aabb);
	}

	// Returns the placed box, which may be bigger than the given box
	AABB reallyPlaceBox(AABB aabb)
	in {
		foreach (box; boxen)
			assert (!box.contains(aabb));
	} out (result) {

		assert (result.contains(aabb));

		bool found = false;
		foreach (box; boxen) {
			assert (!found);
			if (box == result) {
				found = true;
				break;
			}
		}
		assert (found);

	} body {
		++stats.space.boxesPlaced;

		auto beg = aabb.beg, end = aabb.end;
		size_t food = void;
		size_t foodSize = 0;
		size_t usedCells = aabb.size;

		auto eater = AABB.unsafe(aabb.beg, aabb.end);

		auto subsumes   = new size_t[boxen.length];
		auto candidates = new size_t[boxen.length];
		foreach (i, ref c; candidates)
			c = i;

		size_t s = 0;

		for (;;) {
			// Disjoint assumes that it comes after fusables. Some reasoning for
			// why that's probably a good idea anyway:
			//
			// F
			// FD
			// A
			//
			// F is fusable, D disjoint. If we looked for disjoints before
			// fusables, we might subsume D, leaving us worse off than if we'd
			// subsumed F.
			    subsumeContains(candidates, subsumes, s, eater, food, foodSize, usedCells);
			if (subsumeFusables(candidates, subsumes, s, eater, food, foodSize, usedCells)) continue;
			if (subsumeDisjoint(candidates, subsumes, s, eater, food, foodSize, usedCells)) continue;
			if (subsumeOverlaps(candidates, subsumes, s, eater, food, foodSize, usedCells)) continue;
			break;
		}

		if (s)
			aabb = consumeSubsume!(dim)(boxen, subsumes[0..s], food, eater);
		else
			aabb.alloc;

		boxen ~= aabb;
		stats.newMax(stats.space.maxBoxesLive, boxen.length);

		foreach (c; cursors)
			c.invalidate();

		return aabb;
	}

	// Doesn't return bool like the others since it doesn't change eater
	void subsumeContains(
		ref size_t[] candidates, ref size_t[] subsumes, ref size_t sLen,
		AABB eater,
		ref size_t food, ref size_t foodSize,
		ref size_t usedCells)
	{
		for (size_t i = 0; i < candidates.length; ++i) {
			auto c = candidates[i];
			if (eater.contains(boxen[c])) {
				// WORKAROUND: http://d.puremagic.com/issues/show_bug.cgi?id=1715
				Coords* NULL = null;

				subsumes[sLen++] = c;
				minMaxSize!(dim)(boxen, NULL, NULL, food, foodSize, usedCells, c);
				candidates.removeAt(i--);

				++stats.space.subsumedContains;
			}
		}
	}
	bool subsumeFusables(
		ref size_t[] candidates, ref size_t[] subsumes, ref size_t sLen,
		ref AABB eater,
		ref size_t food, ref size_t foodSize,
		ref size_t usedCells)
	{
		auto start = sLen;

		// Get all the fusables first
		//
		// Somewhat HACKY to avoid memory allocation: subsumes[start..sLen] are
		// indices to candidates, not boxen
		foreach (i, c; candidates)
			if (eater.canFuseWith(boxen[c]))
				subsumes[sLen++] = i;

		// Now grab those that we can actually fuse, preferring those along the
		// primary axis (y for 2D, z for 3D)
		//
		// This ensures that all the ones we fuse with are along the same axis.
		// For instance, A can't fuse with both X and Y in the following:
		//
		// X
		// AY
		//
		// Not needed for 1D since they're trivially all along the same axis.
		static if (dim > 1) if (sLen - start > 1) {
			size_t j = start;
			for (size_t i = start; i < sLen; ++i) {
				auto c = candidates[subsumes[i]];
				if (eater.onSamePrimaryAxisAs(boxen[c]))
					subsumes[j++] = subsumes[i];
			}

			if (j == start) {
				j = start + 1;
				auto orig = boxen[candidates[subsumes[start]]];
				for (size_t i = j; i < sLen; ++i)
					if (orig.onSameAxisAs(boxen[candidates[subsumes[i]]]))
						subsumes[j++] = subsumes[i];
			}
			sLen = j;
		}

		assert (sLen >= start);
		if (sLen == start)
			return false;
		else {
			// Sort them so that we can find the correct offset to apply to the
			// array index (since we're removing these from candidates as we go):
			// if the lowest index is always next, the following ones' indices are
			// reduced by one
			subsumes[start..sLen].sort;

			size_t offset = 0;
			foreach (ref s; subsumes[start..sLen]) {
				auto corrected = s - offset++;
				s = candidates[corrected];

				minMaxSize!(dim)(
					boxen, &eater.beg, &eater.end, food, foodSize, usedCells, s);
				candidates.removeAt(corrected);

				++stats.space.subsumedFusables;
			}
			return true;
		}
	}
	bool subsumeDisjoint(
		ref size_t[] candidates, ref size_t[] subsumes, ref size_t sLen,
		ref AABB eater,
		ref size_t food, ref size_t foodSize,
		ref size_t usedCells)
	{
		auto dg = (AABB b, AABB fodder, size_t usedCells) {
			return cheaperToAlloc(b.size, usedCells + fodder.size);
		};

		auto orig = sLen;
		for (size_t i = 0; i < candidates.length; ++i) {
			auto c = candidates[i];

			// All fusables have been removed so a sufficient condition for
			// disjointness is non-overlappingness
			if (!eater.overlaps(boxen[c])
			 && validMinMaxSize!(dim)(
			    	dg, boxen, eater.beg, eater.end, food, foodSize, usedCells, c))
			{
				subsumes[sLen++] = c;
				candidates.removeAt(i--);

				++stats.space.subsumedDisjoint;
			}
		}
		assert (sLen >= orig);
		return sLen > orig;
	}
	bool subsumeOverlaps(
		ref size_t[] candidates, ref size_t[] subsumes, ref size_t sLen,
		ref AABB eater,
		ref size_t food, ref size_t foodSize,
		ref size_t usedCells)
	{
		auto dg = (AABB b, AABB fodder, size_t usedCells) {
			AABB overlap = void;
			size_t overSize = 0;

			if (eater.getOverlapWith(fodder, overlap))
				overSize = overlap.size;

			return cheaperToAlloc(
				b.size, usedCells + fodder.size - overSize);
		};

		auto orig = sLen;
		for (size_t i = 0; i < candidates.length; ++i) {
			auto c = candidates[i];

			if (eater.overlaps(boxen[c])
			 && validMinMaxSize!(dim)(
			    	dg, boxen, eater.beg, eater.end, food, foodSize, usedCells, c))
			{
				subsumes[sLen++] = c;
				candidates.removeAt(i--);
				++stats.space.subsumedOverlaps;
			}
		}
		assert (sLen >= orig);
		return sLen > orig;
	}

	// Takes ownership of the Array, detaching it.
	public void load(Array arr, Coords* end, Coords target, bool binary) {

		scope (exit) arr.detach;

		auto input = cast(ubyte[])arr.slice;

		static if (befunge93) {
			assert (target == 0);
			assert (end is null);
			assert (!binary);

			befunge93Load(input);
		} else {
			auto aabb = getAABB(input, binary, target);

			if (aabb.end.x < aabb.beg.x)
				return;

			aabb.finalize;

			if (end)
				end.maxWith(aabb.end);

			placeBox(aabb);

			auto cursor = Cursor(target, null, this);

			if (binary) {
				foreach (b; input)
					if (b != ' ')
						cursor.set(cast(cell)b);
			} else {
				static if (dim >= 2) {
					bool gotCR = false;

					void newLine() {
						gotCR = false;
						cursor.relPos.x = target.x - cursor.oBeg.x;
						cursor.relPos.y++;
					}
				}

				foreach (b; input) switch (b) {
					case '\r': static if (dim >= 2) gotCR = true; break;
					case '\n': static if (dim >= 2) newLine();    break;
					case '\f':
						static if (dim >= 2)
							if (gotCR)
								newLine();

						static if (dim >= 3) {
							cursor.relPos.x = target.x - cursor.oBeg.x;
							cursor.relPos.y = target.y - cursor.oBeg.y;
							cursor.relPos.z++;
						}
						break;
					case ' ':
						static if (dim >= 2)
							if (gotCR)
								newLine();
						cursor.relPos.x++;
						break;
					default:
						static if (dim >= 2)
							if (gotCR)
								newLine();

						cursor.set(cast(cell)b);
						cursor.relPos.x++;
						break;
				}
			}
		}
	}

	static if (befunge93)
	void befunge93Load(ubyte[] input) {
		auto aabb = AABB(getBeg(), getEnd());
		aabb.alloc;
		boxen ~= aabb;

		bool gotCR = false;
		auto pos = InitCoords!(0,0);

		bool newLine() {
			gotCR = false;
			pos.x = 0;
			++pos.y;
			return pos.y >= 25;
		}

		loop: for (size_t i = 0; i < input.length; ++i) switch (input[i]) {
			case '\r': gotCR = true; break;
			case '\n':
				if (newLine())
					break loop;
				break;
			default:
				if (gotCR && newLine())
					break loop;

				if (input[i] != ' ')
					aabb[pos] = cast(cell)input[i];

				if (++pos.x < 80)
					break;

				++i;
				skipRest: for (; i < input.length; ++i) switch (input[i]) {
					case '\r': gotCR = true; break;
					case '\n':
						if (newLine())
							break loop;
						break skipRest;
					default:
						if (gotCR) {
							if (newLine())
								break loop;
							break skipRest;
						}
						break;
				}
				break;
		}
	}

	// If nothing would be loaded, end.x < beg.x in the return value
	//
	// target: where input is being loaded to
	AABB getAABB(
		ubyte[] input,
		bool binary,
		Coords target)
	{
		Coords beg = void;
		Coords end = target;

		if (binary) {
			beg = target;

			size_t i = 0;
			while (i < input.length && input[i++] == ' '){}

			beg.x += i-1;

			// If i == input.length it was all spaces
			if (i != input.length) {
				i = input.length;
				while (i > 0 && input[--i] == ' '){}

				end.x += i;
			}

			return AABB.unsafe(beg, end);
		}

		beg = InitCoords!(cell.max,cell.max,cell.max);
		ubyte getBeg = 0b111;
		auto pos = target;
		auto lastNonSpace = end;

		static if (dim >= 2) {
			bool gotCR = false;

			void newLine() {
				end.x = max(lastNonSpace.x, end.x);

				pos.x = target.x;
				++pos.y;
				gotCR = false;
				getBeg = 0b001;
			}
		}

		foreach (b; input) switch (b) {
			case '\r':
				static if (dim >= 2)
					gotCR = true;
				break;

			case '\n':
				static if (dim >= 2)
					newLine();
				break;

			case '\f':
				static if (dim >= 2)
					if (gotCR)
						newLine();

				static if (dim >= 3) {
					end.x = max(lastNonSpace.x, end.x);
					end.y = max(lastNonSpace.y, end.y);

					pos.x = target.x;
					pos.y = target.y;
					++pos.z;
					getBeg = 0b011;
				}
				break;

			default:
				static if (dim >= 2)
					if (gotCR)
						newLine();

				if (b != ' ') {
					lastNonSpace = pos;

					if (getBeg) for (size_t i = 0; i < dim; ++i) {
						auto mask = 1 << i;
						if (getBeg & mask && pos.v[i] < beg.v[i]) {
							beg.v[i] = pos.v[i];
							getBeg &= ~mask;
						}
					}
				}
				++pos.x;
				break;
		}
		end.maxWith(lastNonSpace);

		return AABB.unsafe(beg, end);
	}

	bool cheaperToAlloc(size_t together, size_t separate) {
		return
			together <= ACCEPTABLE_WASTE ||
			  cell.sizeof * (together - ACCEPTABLE_WASTE)
			< cell.sizeof * separate + AABB.sizeof;
	}

	// Outputs space in the range [beg,end).
	// Puts form feeds / line breaks only between rects/lines.
	// Doesn't trim trailing spaces or anything like that.
	// Doesn't close the given OutputStream.
	public void binaryPut(OutputStream file, Coords!(3) beg, Coords!(3) end) {
		scope tfile = new TypedOutput!(ubyte)(file);
		scope (exit) tfile.flush;

		Coords c = void;
		ubyte b  = void;
		for (cell z = beg.z; z < end.z;) {

			static if (dim >= 3) c.z = z;

			for (cell y = beg.y; y < end.y;) {

				static if (dim >= 2) c.y = y;

				for (cell x = beg.x; x < end.x; ++x) {
					c.x = x;
					b = cast(ubyte)this[c];
					tfile.write(b);
				}
				if (++y != end.y) foreach (ch; NewlineString) {
					b = ch;
					tfile.write(b);
				}
			}

			if (++z != end.z) {
				b = '\f';
				tfile.write(b);
			}
		}
	}

	public void informOf(Cursor* c) { cursors ~= c; }
}

struct Cursor(cell dim, bool befunge93) {
private:
	alias .Coords    !(dim)            Coords;
	alias .Dimension !(dim).Coords     InitCoords;
	alias .Dimension !(dim).contains   contains;
	alias .AABB      !(dim)            AABB;
	alias .FungeSpace!(dim, befunge93) FungeSpace;

	Coords relPos = void, oBeg = void, ob2b = void, ob2e = void;
	AABB box = void;
	size_t boxIdx = void;

public:
	FungeSpace space;

	private bool inBox() { return contains(relPos, ob2b, ob2e); }

	cell get() {
		if (!inBox()) {
			auto p = pos;
			if (!getBox(p))
				return ' ';
		}
		return unsafeGet();
	}
	cell unsafeGet() in { assert (inBox()); }
	               body { return  box.getNoOffset(relPos); }

	void set(cell c) {
		if (!inBox()) {
			auto p = pos;
			if (!getBox(p))
				return space[p] = c;
		}
		unsafeSet(c);
	}
	void unsafeSet(cell c) in { assert (inBox()); }
	                     body { box.setNoOffset(relPos, c); }

	Coords pos()         { return relPos + oBeg; }
	void   pos(Coords c) { relPos = c - oBeg; }

	static typeof(*this) opCall(Coords c, Coords* delta, FungeSpace s) {

		typeof(*this) cursor;
		with (cursor) {
			space = s;

			if (!space.findBox(c, box, boxIdx)) {

				assert (delta !is null);

				if (space.tryJumpToBox(c, *delta, boxIdx))
					box = space.boxen[boxIdx];

				else version (detectInfiniteLoops)
					throw new InfiniteLoopException(
						"IP diverged while being placed",
						c.toString(), delta.toString());
				else
					for (;;){}
			}
			tessellate(c);
		}
		return cursor;
	}

	private void invalidate() {
		auto p = pos;
		if (!getBox(p))
			// Just grab a box which we aren't contained in; skipMarkers will sort
			// it out
			box = space.boxen[boxIdx = 0];
	}

	private void tessellate(Coords p) {
		// Care only about boxes that are above box
		auto overlaps = new AABB[boxIdx];
		size_t i = 0;
		foreach (b; space.boxen[0..boxIdx])
			if (b.overlaps(box))
				overlaps[i++] = b;

		oBeg = box.beg;
		relPos = p - oBeg;
		box = box.tessellationAt(p, overlaps[0..i]);
		ob2b = box.beg - oBeg;
		ob2e = box.end - oBeg;
	}

	private bool getBox(ref Coords p) {
		if (space.findBox(p, box, boxIdx)) {
			tessellate(p);
			return true;
		} else
			return false;
	}

	void advance(Coords delta) { relPos += delta; }
	void retreat(Coords delta) { relPos -= delta; }

	template DetectInfiniteLoopDecls() {
		version (detectInfiniteLoops) {
			Coords firstExit;
			bool gotFirstExit = false;
		}
	}
	template DetectInfiniteLoop(char[] doing) {
		const DetectInfiniteLoop = `
			version (detectInfiniteLoops) {
				if (gotFirstExit) {
					if (relPos == firstExit)
						throw new InfiniteLoopException(
							"Found itself whilst ` ~doing~ `",
							(relPos + oBeg).toString(), delta.toString());
				} else {
					firstExit    = relPos;
					gotFirstExit = true;
				}
			}
		`;
	}

	void skipMarkers(Coords delta)
	out {
		assert (get() != ' ');
		assert (get() != ';');
	} body {
		mixin DetectInfiniteLoopDecls!();

		if (!inBox())
			goto findBox;

		switch (unsafeGet()) {
			do {
			case ' ':
				while (!box.skipSpacesNoOffset(relPos, delta, ob2b, ob2e)) {
findBox:
					auto p = pos;
					if (!getBox(p)) {
						mixin (DetectInfiniteLoop!("processing spaces"));
						tessellate(space.jumpToBox(p, delta, box, boxIdx));
					}
				}
				if (unsafeGet() == ';') {
			case ';':
					bool status = false;
					while (
						!box.skipSemicolonsNoOffset(
							relPos, delta, ob2b, ob2e, status))
					{
						auto p = pos;
						if (!getBox(p)) {
							mixin (DetectInfiniteLoop!("jumping over semicolons"));
							tessellate(space.jumpToBox(p, delta, box, boxIdx));
						}
					}
				}
			} while (unsafeGet() == ' ')

			default: break;
		}
	}
	void skipToLastSpace(Coords delta) {
		if (inBox()) {
contained:
			if (unsafeGet() == ' ') {
				mixin DetectInfiniteLoopDecls!();

				while (!box.skipSpacesNoOffset(relPos, delta, ob2b, ob2e)) {
					auto p = pos;
					if (!getBox(p)) {
						mixin (DetectInfiniteLoop!("processing spaces"));
						tessellate(space.jumpToBox(p, delta, box, boxIdx));
					}
				}
				relPos -= delta;
			}
		} else {
			auto p = pos;
			if (space.tryJumpToBox(p, delta, boxIdx)) {
				box = space.boxen[boxIdx];
				tessellate(p);
				goto contained;

			} else version (detectInfiniteLoops)
				throw new InfiniteLoopException(
					"Never meets an allocated area",
					p.toString(), delta.toString());
			else
				for (;;){}
		}
	}
}

// Functions that don't need to live inside any of the aggregates
private:

// Finds the bounds of the tightest AABB containing all the boxen referred by
// indices, as well as the largest box among them, and keeps a running sum of
// their lengths.
//
// Assumes they're all allocated and max isn't.
void minMaxSize(cell dim)
	(AABB!(dim)[] boxen,
	 Coords!(dim)* beg, Coords!(dim)* end,
	 ref size_t max, ref size_t maxSize,
	 ref size_t length,
	 size_t[] indices)
{
	foreach (i; indices)
		minMaxSize!(dim)(boxen, beg, end, max, maxSize, length, i);
}

void minMaxSize(cell dim)
	(AABB!(dim)[] boxen,
	 Coords!(dim)* beg, Coords!(dim)* end,
	 ref size_t max, ref size_t maxSize,
	 ref size_t length,
	 size_t i)
{
	auto box = boxen[i];
	length += box.size;
	if (box.size > maxSize) {
		maxSize = box.size;
		max = i;
	}
	if (beg) beg.minWith(box.beg);
	if (end) end.maxWith(box.end);
}

// The input delegate takes:
// - box that subsumes (unallocated)
// - box to be subsumed (allocated)
// - number of cells that are currently contained in any box that the subsumer
//   contains
size_t validMinMaxSize(cell dim)
	(bool delegate(AABB!(dim), AABB!(dim), size_t) valid,
	 AABB!(dim)[] boxen,
	 ref Coords!(dim) beg, ref Coords!(dim) end,
	 ref size_t max, ref size_t maxSize,
	 ref size_t length,
	 size_t idx)
{
	auto
		tryBeg = beg, tryEnd = end,
		tryMax = max, tryMaxSize = maxSize,
		tryLen = length;

	minMaxSize!(dim)(boxen, &tryBeg, &tryEnd, tryMax, tryMaxSize, tryLen, idx);

	if (valid(AABB!(dim)(tryBeg, tryEnd), boxen[idx], length)) {
		beg     = tryBeg;
		end     = tryEnd;
		max     = tryMax;
		maxSize = tryMaxSize;
		length  = tryLen;
		return true;
	} else
		return false;
}

AABB!(dim) consumeSubsume(cell dim)
	(ref AABB!(dim)[] boxen, size_t[] subsumes, size_t food, AABB!(dim) aabb)
{
	irrelevizeSubsumptionOrder!(dim)(boxen, subsumes);

	aabb.finalize;
	aabb.consume(boxen[food]);

	// NOTE: strictly speaking this should be a foreach_reverse and subsumes
	// should be sorted, since we don't want below-boxes to overwrite
	// top-boxes' data. However, irrelevizeSubsumptionOrder copies the data so
	// that the order is, in fact, irrelevant.
	//
	// I think that 'food' would also have to be simply subsumes[$-1] after
	// sorting, but I haven't thought this completely through so I'm not
	// sure.
	//
	// In debug mode, do exactly the "wrong" thing (subsume top-down), in the
	// hopes of bug catching.
	debug subsumes.sort;

	foreach (i; subsumes) if (i != food) {
		aabb.subsume(boxen[i]);
		free(boxen[i].data);
	}

	outer: for (size_t i = 0, n = 0; i < boxen.length; ++i) {
		foreach (s; subsumes) {
			if (i == s-n) { boxen.removeAt(i--); ++n; }
			if (boxen.length == 0) break outer;
		}
	}

	return aabb;
}

// Consider the following:
//
// +-----++---+
// | A +--| C |
// +---|B +*--+
//     +----+
//
// Here, A is the one being placed and C is a fusable. * is a point whose
// data is in C but which is contained in both B and C. Since the final
// subsumer-box is going to be below all existing boxes, we'll end up
// with:
//
// +----------+
// | X +----+ |
// +---|B  *|-+
//     +----+
//
// Where X is the final box placed. Note that * is now found in B, not in
// X, but its data was in C (now X)! Oops!
//
// So, we do the following, which in the above case would copy the data
// from C to B.
//
// Caveats:
//   1. This assumes that the final box will always be placed
//      bottom-most. This does not really matter, it's just extra work if
//      it's not; but in any case, if not, the relevant overlapping boxes
//      would be those which would end up above the final box.
//
//   2. This leaves some non-space data in an unaccessible area of a
//      below-box. If something ends up assuming that such areas are all
//      spaces (at the time of writing, nothing does), this should be
//      amended to write spaces onto the below-box.
void irrelevizeSubsumptionOrder(cell dim)
	(AABB!(dim)[] boxen, size_t[] subsumes)
{
	foreach (i; subsumes) {
		// Check boxes below boxen[i]
		AABB!(dim) overlap = void;
		for (auto j = i+1; j < boxen.length; ++j) {

			if (boxen[i].contains(boxen[j]) || boxen[j].contains(boxen[i]))
				continue;

			// If they overlap, copy the overlap area to the lower box
			if (boxen[i].getOverlapWith(boxen[j], overlap))
				boxen[j].subsumeArea(boxen[i], overlap);
		}
	}
}

enum I1D {
	NONE,
	END_IN,
	BEG_IN,
	BOTH_OUT
}
// Assumes that boxB–boxE doesn't contain b–e
I1D intersect1D(cell b, cell e, cell boxB, cell boxE) {
	if (e >= boxB) {
		if (e <= boxE)
			return I1D.END_IN;
		else if (b <= boxE) {
			// e is past the box and b isn't
			return b < boxB ? I1D.BOTH_OUT : I1D.BEG_IN;
		}
	}
	return I1D.NONE;
}

final class InfiniteLoopException : Exception {
	this(char[] msg, char[] pos, char[] delta) {
		super(
			"Funge-Space detected eternal loop from " ~ pos ~
			" with delta " ~ delta ~
			": " ~ msg);
	}
}
