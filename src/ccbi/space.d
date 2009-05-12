// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2006-06-09 17:34:29

// Funge-Space and the Coords struct.
module ccbi.space;

import tango.io.device.Array      : Array;
import tango.io.model.IConduit    : OutputStream;
import tango.io.stream.Typed      : TypedOutput;
import tango.math.Math            : min, max;
import tango.stdc.string          : memmove;
import tango.text.convert.Integer : format;

public import ccbi.cell;
       import ccbi.templateutils;
       import ccbi.stats;
       import ccbi.stdlib;
       import ccbi.utils;

struct Coords(cell dim) {
	static assert (dim >= 1 && dim <= 3);

	                       cell x;
	static if (dim >= 2) { cell y; }
	static if (dim >= 3) { cell z; }

	char[] toString() {
		char[ToString!(cell.min).length] buf = void;

		char[] s = "(";
		                                 s ~= format(buf, x);
		static if (dim >= 2) { s ~= ','; s ~= format(buf, y); }
		static if (dim >= 3) { s ~= ','; s ~= format(buf, z); }
		s ~= ')';
		return s;
	}

	Coords!(3) extend(cell val) {
		Coords!(3) c;
		static if (dim >= 3) { c.z = z; } else c.z = val;
		static if (dim >= 2) { c.y = y; } else c.y = val;
		                       c.x = x;
		return c;
	}

	int opEquals(cell c) {
		static if (dim >= 3) if (z != c) return false;
		static if (dim >= 2) if (y != c) return false;
		return x == c;
	}
	int opEquals(Coords c) {
		static if (dim >= 3) if (z != c.z) return false;
		static if (dim >= 2) if (y != c.y) return false;
		return x == c.x;
	}

	template Ops(T...) {
		static assert (T.length != 1);

		static if (T.length == 0)
			const Ops = "";
		else
			const Ops =
				"Coords op" ~T[0]~ "(cell c) {
					Coords co = *this;
					                     co.x "~T[1]~"= c;
					static if (dim >= 2) co.y "~T[1]~"= c;
					static if (dim >= 3) co.z "~T[1]~"= c;
					return co;
				}
				void op" ~T[0]~ "Assign(cell c) {
					                     x "~T[1]~"= c;
					static if (dim >= 2) y "~T[1]~"= c;
					static if (dim >= 3) z "~T[1]~"= c;
				}

				Coords op" ~T[0]~ "(Coords c) {
					Coords co = *this;
					                     co.x "~T[1]~"= c.x;
					static if (dim >= 2) co.y "~T[1]~"= c.y;
					static if (dim >= 3) co.z "~T[1]~"= c.z;
					return co;
				}
				void op" ~T[0]~ "Assign(Coords c) {
					                     x "~T[1]~"= c.x;
					static if (dim >= 2) y "~T[1]~"= c.y;
					static if (dim >= 3) z "~T[1]~"= c.z;
				}"
				~ Ops!(T[2..$]);
	}

	mixin (Ops!(
		"Mul", "*",
		"Add", "+",
		"Sub", "-"
	));

	// {{{ MurmurHash 2.0, thanks to Austin Appleby
	// at http://murmurhash.googlepages.com/
	hash_t toHash() {
		const hash_t m = 0x_5bd1_e995;

		hash_t h = 0x7fd6_52ad ^ (x.sizeof * dim), k;

			k = x; k *= m; k ^= k >> 24; k *= m; h *= m; h ^= k;
		static if (dim >= 2) {
			k = y; k *= m; k ^= k >> 24; k *= m; h *= m; h ^= k;
		}
		static if (dim >= 3) {
			k = z; k *= m; k ^= k >> 24; k *= m; h *= m; h ^= k;
		}

		h ^= h >> 13;
		h *= m;
		h ^= h >> 15;

		return h;
	} // }}}
}

template Dimension(cell dim) {
	template Coords(cell x, cell y, cell z) {
		     static if (dim == 1) const Coords = .Coords!(dim)(x);
		else static if (dim == 2) const Coords = .Coords!(dim)(x,y);
		else static if (dim == 3) const Coords = .Coords!(dim)(x,y,z);
	}
	template Coords(cell x, cell y) {
		const Coords = Coords!(x,y,0);
	}
	template Coords(cell x) {
		const Coords = Coords!(x,0,0);
	}
}

private struct AABB(cell dim) {
	static assert (dim >= 1 && dim <= 3);

	alias .Coords!(dim) Coords;

	typedef cell initcell = ' ';
	union {
		initcell[] data;
		size_t size;
	}
	Coords beg, end;

	static if (dim >= 2) size_t width;
	static if (dim >= 3) size_t area;

	static typeof(*this) opCall(Coords b, Coords e)
	in {
		                     assert (b.x <= e.x);
		static if (dim >= 2) assert (b.y <= e.y);
		static if (dim >= 3) assert (b.z <= e.z);
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
		auto size = size;
		data = null;
		data = new typeof(data)(size);
	}

	int opEquals(AABB b) { return beg == b.beg && end == b.end; }

	bool contains(Coords p) {
		                     if (!(p.x >= beg.x && p.x <= end.x)) return false;
      static if (dim >= 2) if (!(p.y >= beg.y && p.y <= end.y)) return false;
      static if (dim >= 3) if (!(p.z >= beg.z && p.z <= end.z)) return false;

		return true;
	}
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
		assert (getIdx(p) < data.length);
	} body {
		return cast(cell)data[getIdx(p)];
	}
	cell opIndexAssign(cell val, Coords p)
	in {
		assert (this.contains(p));

		// Ditto above
		assert (data !is null);
		assert (getIdx(p) < data.length);
	} body {
		return cast(cell)(data[getIdx(p)] = cast(initcell)val);
	}
	private size_t getIdx(Coords p) {
		p -= beg;

		size_t idx = p.x;

		static if (dim >= 2) idx += width * p.y;
		static if (dim >= 3) idx += area  * p.z;

		return idx;
	}

	bool overlaps(AABB b) {
		bool over = beg.x <= b.end.x && b.beg.x <= end.x;

		static if (dim >= 2)
			over = over && beg.y <= b.end.y && b.beg.y <= end.y;

		static if (dim >= 3)
			over = over && beg.z <= b.end.z && b.beg.z <= end.z;

		return over;
	}
	bool getOverlapWith(AABB box, ref AABB overlap)
	in {
		// Allows us to make some assumptions
		assert (!this.contains(box));
		assert (!box.contains(*this));
	} body {
		static if (dim == 1) {
			// FIXME
			assert (0, "NOT DONE: 1D overlap finding");
		} else static if (dim == 2) {
			auto
				overBeg = Coords(cell.max, cell.max),
				overEnd = Coords(cell.min, cell.min);

			// We'll get more than two points so else-if is fine
			void addPoint(Coords p) {
				     if (p.x < overBeg.x) overBeg.x = p.x;
				else if (p.x > overEnd.x) overEnd.x = p.x;
				     if (p.y < overBeg.y) overBeg.y = p.y;
				else if (p.y > overEnd.y) overEnd.y = p.y;
			}

			bool intersected = false;

			void intersect(Coords p1, Coords p2) {
				intersected = true;

				static byte intersect1D(
					cell b, cell e, cell compareBeg, cell compareEnd)
				{
					if (e >= compareBeg) {
						if (e <= compareEnd) {
							// e is in box: we know b isn't since !this.contains(box)
							return 0;
						} else if (b <= compareEnd) {
							// e is past the box and b isn't
							return b <= compareBeg ? 2 : 1;
						}
					}
					return -1;
				}
				cell b, e;

				// p1-p2 is axis-aligned: x or y?
				if (p1.x == p2.x) {
					// y
					if (p1.y < p2.y) { b = p1.y; e = p2.y; }
					else             { b = p2.y; e = p1.y; }

					switch (intersect1D(b, e, box.beg.y, box.end.y)) {
						case 2: addPoint(Coords(p1.x, box.beg.y));
						case 1: addPoint(Coords(p1.x, box.end.y)); break;
						case 0: addPoint(Coords(p1.x, box.beg.y)); break;
						default: break;
					}
				} else {
					// x
					if (p1.x < p2.x) { b = p1.x; e = p2.x; }
					else             { b = p2.x; e = p1.x; }

					switch (intersect1D(b, e, box.beg.x, box.end.x)) {
						case 2: addPoint(Coords(box.beg.x, p1.y));
						case 1: addPoint(Coords(box.end.x, p1.y)); break;
						case 0: addPoint(Coords(box.beg.x, p1.y)); break;
					}
				}
			}

			// Sutherland-Hodgman

			auto ne = Coords(end.x, beg.y);
			auto sw = Coords(beg.x, end.y);
			auto prev = sw;

			foreach (pt; [beg, ne, end, sw]) {
				if (box.contains(pt)) {
					if (!box.contains(prev))
						intersect(prev, pt);

					addPoint(pt);

				} else if (box.contains(prev))
					intersect(pt, prev);

				prev = pt;
			}

			if (intersected)
				overlap = AABB(overBeg, overEnd);

			return intersected;

		} else static if (dim == 3) {
			// FIXME
			// Sutherland-Hodgman
			assert (0, "NOT DONE: 3D overlap finding");
		}
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

	bool canDirectCopy(AABB box) {
		static if (dim == 1) return true;
		else if (box.size <= this.width) return true;
		static if (dim == 2) return width == box.width;
		static if (dim == 3) return width == box.width && area == box.area;
	}

	// This should be unallocated, the other allocated. Can't be checked in the
	// contract due to the union.
	//
	// Takes ownership of old's array: it must be contained within this.
	void consume(AABB old)
	in {
		assert (this.contains(old));
	} body {
		auto oldLength = old.data.length;

		old.data.length = size;
		data = old.data;

		auto oldIdx = this.getIdx(old.beg);

		if (canDirectCopy(old)) {
			bool overlapping = oldIdx < oldLength;

			if (overlapping)
				memmove(&data[oldIdx], data.ptr, oldLength * cell.sizeof);
			else
				data[oldIdx..oldIdx + oldLength] = data[0..oldLength];
			data[0..oldLength] = ' ';

		} else static if (dim == 2) {

			bool overlapping = oldIdx < old.width;

			auto iend = oldIdx + (beg == old.beg ? old.width : 0);
			auto oldEnd = oldIdx + oldLength / old.width * width;

			for (auto i = oldEnd, j = oldLength; i > iend;) {
				i -= this.width;
				j -=  old.width;

				if (overlapping)
					memmove(&data[i], &data[j], old.width * cell.sizeof);
				else
					data[i..i+old.width] = data[j..j+old.width];
				data[j..j+old.width] = ' ';
			}
		} else static if (dim == 3) {

			bool overlapping = oldIdx < old.width;

			auto sameBeg = beg == old.beg;
			auto iend = oldIdx + (sameBeg && width == old.width ? old.area : 0);
			auto oldEnd = oldIdx + oldLength / old.area * area;

			for (auto i = oldEnd, j = oldLength; i > iend;) {
				i -= this.area;
				j -=  old.area;

				auto kend = i + (sameBeg ? old.width : 0);

				for (auto k = i + old.area/old.width*width, l = j; k > kend;) {
					k -= this.width;
					l -=  old.width;

					if (overlapping)
						memmove(&data[k], &data[l], old.width * cell.sizeof);
					else
						data[k..k+old.width] = data[l..l+old.width];
					data[l..l+old.width] = ' ';
				}
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
		subsumeArea(old, old.data);
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
		subsumeArea(area, b.data[b.getIdx(area.beg)..b.getIdx(area.end)+1]);
	}

	// Internal: copies the cells in area from the given array to this.
	void subsumeArea(AABB area, initcell[] data)
	in {
		assert (this.contains(area));
		assert (area.size == data.length);
	} out {
		assert ((*this)[area.beg] == data[0]  );
		assert ((*this)[area.end] == data[$-1]);
	} body {
		auto begIdx = this.getIdx(area.beg);

		if (canDirectCopy(area))
			this.data[begIdx .. begIdx + area.size] = data;

		else static if (dim == 2) {
			for (size_t i = 0, j = begIdx; i < data.length;) {
				this.data[j .. j+area.width] = data[i..i+area.width];
				i += area.width;
				j += this.width;
			}

		} else static if (dim == 3) {
			for (size_t i = 0, j = begIdx; i < data.length;) {
				for (size_t k = i, l = j; k < i + area.area;) {
					this.data[l .. l+area.width] = data[k..k+area.width];
					k += area.width;
					l += this.width;
				}
				i += area.area;
				j += this.area;
			}
		}
	}
}

final class FungeSpace(cell dim, bool befunge93) {
	static assert (dim >= 1 && dim <= 3);
	static assert (!befunge93 || dim == 2);

	alias .AABB     !(dim) AABB;
	alias .Coords   !(dim) Coords;
	alias .Dimension!(dim).Coords InitCoords;

	private const NEWBOX_PAD = 8;

	Stats* stats;

	// These are array indices, starting from 0. Thus the in-use map size is
	// (end.x - beg.x + 1) * (end.y - beg.y + 1) * (end.z - beg.z + 1).
	//
	// Initialize so that min/max give what we want. end can't be negative
	// initially so 0 is fine, and beg.y and beg.z must be zero or nothing is
	// ever executed, so 0 is fine there as well.
	Coords
		beg = InitCoords!(cell.max),
		end = InitCoords!(0);

	private AABB[] boxen;

	this(Stats* stats, Array source) {
		this.stats = stats;

		load(source, &end, InitCoords!(0), false, false);

		                     assert (beg.x >= 0);
		static if (dim >= 2) assert (beg.y >= 0);
		static if (dim >= 3) assert (beg.z >= 0);
	}

	this(FungeSpace other) {
		shallowCopy(this, other);

		// deep copy space
		boxen = other.boxen.dup;
		foreach (i, ref aabb; boxen)
			aabb.data = aabb.data.dup;
	}

	bool inBounds(Coords c) {
		static if (dim == 3) return
			c.x >= beg.x && c.x <= end.x &&
			c.y >= beg.y && c.y <= end.y &&
			c.z >= beg.z && c.z <= end.z;
		else static if (dim == 2) return
			c.x >= beg.x && c.x <= end.x &&
			c.y >= beg.y && c.y <= end.y;
		else return
			c.x >= beg.x && c.x <= end.x;
	}

	cell opIndex(Coords c) {
		++stats.spaceLookups;

		foreach (aabb; boxen)
			if (aabb.contains(c))
				return aabb[c];
		return ' ';
	}
	cell opIndexAssign(cell v, Coords c) {
		++stats.spaceAssignments;

		if (v != ' ')
			growBegEnd(c);

		foreach (aabb; boxen)
			if (aabb.contains(c))
				return aabb[c] = v;

		foreach (aabb; reallyPlaceBox(AABB(c - NEWBOX_PAD, c + NEWBOX_PAD)))
			if (aabb.contains(c))
				return aabb[c] = v;

		assert (false, "Cell in no box");
	}

	// TODO: shrink bounds sometimes, as well
	void growBegEnd(Coords c) {
			     if (c.x > end.x) end.x = c.x;
			else if (c.x < beg.x) beg.x = c.x;
		static if (dim >= 2) {
			     if (c.y > end.y) end.y = c.y;
			else if (c.y < beg.y) beg.y = c.y; }
		static if (dim >= 3) {
			     if (c.z > end.z) end.z = c.z;
			else if (c.z < beg.z) beg.z = c.z; }
	}

	AABB[] placeBox(AABB aabb) {
		foreach (box; boxen)
			if (box.contains(aabb))
				return [box];

		return reallyPlaceBox(aabb);
	}

	// Returns the new boxes placed
	AABB[] reallyPlaceBox(AABB aabb)
	in {
		foreach (box; boxen)
			assert (!box.contains(aabb));
	} out (result) {

		// Everything in result should be in the same relative order as in boxen,
		// and should be contained in boxen

		size_t prev = boxen.length;

		foreach_reverse (x; result) {
			size_t origIdx = boxen.length;

			foreach (j, y; boxen) if (x == y) {
				origIdx = j;
				break;
			}

			assert (origIdx < prev);
			prev = origIdx;
		}
	} body {
		auto contains = new size_t[boxen.length];
		auto fusables = new size_t[boxen.length];
		auto overlaps = new size_t[boxen.length];
		auto disjoint = new size_t[boxen.length];

		{size_t c = 0, f = 0, o = 0, d = 0;
		foreach (i, box; boxen) {
			if (aabb.canFuseWith(box))
				fusables[f++] = i;
			else if (aabb.overlaps(box)) {
				if (aabb.contains(box))
					contains[c++] = i;
				else
					overlaps[o++] = i;
			} else
				disjoint[d++] = i;
		}
		contains.length = c;
		fusables.length = f;
		overlaps.length = o;
		disjoint.length = d;}

		bool alloced = false;

		if (contains.length || disjoint.length || fusables.length)
			alloced = subsumeAll(aabb, contains, disjoint, fusables, overlaps);

		if (overlaps.length) {
			if (subsumeOverlapping(overlaps, aabb)) {

				assert (false, "Subsumption of overlaps wanted but not tested");
				/+
				auto beg = aabb.beg, end = aabb.end;
				size_t food;
				size_t foodSize = 0;
				size_t unused_length;
				minMaxSize!(dim)
					(boxen, beg, end, food, foodSize, unused_length, overlaps);

				aabb = AABB(beg, end);
				aabb.consume(boxen[food]);

				foreach (i; overlaps)
					if (food != i)
						aabb.subsume(boxen[i]);

				outer: for (size_t i = 0, n = 0; i < boxen.length; ++i) {
					foreach (j; overlaps) {
						if (i == j-n) { boxen.removeAt(i--); ++n; }
						if (boxen.length == 0) break outer;
					}
				}
				alloced = true;
				+/

			} else if (decompose(overlaps, aabb))
				assert (false, "Decomposition wanted but not implemented!");
			else {
				if (!alloced)
					aabb.alloc;
				boxen ~= aabb;

				auto ret = new AABB[overlaps.length + 1];
				foreach (i, b; overlaps)
					ret[i] = boxen[b];
				ret[$-1] = aabb;
				return ret;
			}
		}
		if (!alloced)
			aabb.alloc;
		boxen ~= aabb;
		return [aabb];
	}

	// TODO: if any function here needs cleanup, it's this one
	bool subsumeAll(cell dim)(
		ref AABB!(dim) aabb,
		size_t[] contains, size_t[] disjoint, size_t[] fusables,
		ref size_t[] overlaps)
	{
		auto beg = aabb.beg, end = aabb.end;
		size_t
			food = size_t.max,
			foodSize = 0,
			length = aabb.size;

		minMaxSize!(dim)(boxen, beg, end, food, foodSize, length, contains);

		// Grab those that we can actually fuse, preferring those along the
		// primary axis (y for 2d, z for 3d)
		//
		// This ensures that all in fusables should be along the same axis, we
		// can't fuse A with both X and Y in the following:
		// X
		// AY
		static if (dim > 1) if (fusables.length > 1) {
			size_t j = 0;
			for (size_t i = 0; i < fusables.length; ++i)
				if (aabb.onSamePrimaryAxisAs(boxen[fusables[i]]))
					fusables[j++] = fusables[i];

			if (!j) {
				j = 2;
				for (size_t i = 2; i < fusables.length; ++i)
					if (boxen[fusables[1]].onSameAxisAs(boxen[fusables[i]]))
						fusables[j++] = fusables[i];
			}

			fusables.length = j;
		}
		minMaxSize!(dim)(boxen, beg, end, food, foodSize, length, fusables);

		// Disjoints need to be found last, consider for instance:
		//
		// F
		// FD
		// A
		//
		// F is fusable, D disjoint. If we looked for disjoints before fusables,
		// subsumeDisjoint could return true for D, and we'd be worse off. In
		// general it seems to be a better idea to subsume fusables than
		// disjoints.
		size_t goodDisjoints = 0;
		for (size_t i = 0; i < disjoint.length; ++i) {
			auto box = disjoint[i];

			auto
				tryBeg = beg, tryEnd = end,
				tryFood = food, tryFoodSize = foodSize,
				tryLength = length;
			minMaxSize!(dim)
				(boxen, tryBeg, tryEnd, tryFood, tryFoodSize, tryLength, box);

			if (subsumeDisjoint(AABB(tryBeg, tryEnd), boxen[box], tryLength)) {
				disjoint[goodDisjoints] = box;

				// We need to look at the "bad disjoints" below, so make sure there
				// are no good ones outside the goodDisjoints range
				if (goodDisjoints != i)
					disjoint.removeAt(i--);

				++goodDisjoints;

				beg      = tryBeg;
				end      = tryEnd;
				food     = tryFood;
				foodSize = tryFoodSize;
				length   = tryLength;
			}
		}

		if (goodDisjoints) {
			// New contains may have resulted, and fusables / bad disjoints may
			// have become contains. For now, just add contains and remove old
			// fusables / bad disjoints. See the TODO below for what we should be
			// doing instead.
			//
			// Under our current scheme, at this point it no longer matters which
			// array something is in, so the fusables->contains movement is
			// unnecessary; but it will be necessary in the future, so leave it.
			//
			// New overlaps may also have resulted, but we recalculate those
			// later anyway.
			aabb = AABB(beg, end);

			assert (fusables == fusables.dup.sort);

			auto oldC = contains.length;
			auto c = oldC;
			contains.length = contains.length + disjoint.length - goodDisjoints;

			for (size_t i = goodDisjoints; i < disjoint.length; ++i) {
				auto d = disjoint[i];
				if (aabb.contains(boxen[d])) {
					contains[c++] = d;
					disjoint.removeAt(i--);
				}
			}
			contains.length = c + fusables.length;

			minMaxSize!(dim)
				(boxen, beg, end, food, foodSize, length, contains[oldC..c]);

			for (size_t i = 0; i < fusables.length; ++i) {
				auto f = fusables[i];
				if (aabb.contains(boxen[f])) {
					contains[c++] = f;
					fusables.removeAt(i--);
				}
			}
			contains.length = c;
		}
		disjoint.length = goodDisjoints;

		if (!(contains.length || disjoint.length || fusables.length))
			return false;

		// TODO: iterate the above process: search for new fusables, then
		// disjoints, then contains, then fusables, etc, until we find nothing new

		auto subsumes = contains ~ disjoint ~ fusables;

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
		foreach (i; subsumes) {
			// Check boxes below boxen[i]
			AABB overlap = void;
			for (auto j = i+1; j < boxen.length; ++j) {

				if (boxen[i].contains(boxen[j]) || boxen[j].contains(boxen[i]))
					continue;

				// If they overlap, copy the overlap area to the lower box
				if (boxen[i].getOverlapWith(boxen[j], overlap))
					boxen[j].subsumeArea(boxen[i], overlap);
			}
		}

		aabb = AABB(beg, end);
		aabb.consume(boxen[food]);

		// NOTE: strictly speaking this should be a foreach_reverse and subsumes
		// should be sorted, since we don't want below-boxes to overwrite
		// top-boxes' data. However, the foreach next to the long comment above
		// copies the data so that the order is, in fact, irrelevant.
		//
		// I think that 'food' would also have to be simply subsumes[$-1] after
		// sorting, but I haven't thought this completely through so I'm not
		// sure.
		//
		// In debug mode, do exactly the "wrong" thing (subsume top-down), in the
		// hopes of bug catching.
		debug subsumes.sort;

		foreach (i; subsumes)
			if (i != food)
				aabb.subsume(boxen[i]);

		outer: for (size_t i = 0, n = 0; i < boxen.length; ++i) {
			foreach (s; subsumes) {
				if (i == s-n) { boxen.removeAt(i--); ++n; }
				if (boxen.length == 0) break outer;
			}
		}

		// There might be some things that overlap with this aabb but not the
		// original
		//
		// We know that the original overlaps overlap with aabb, but we don't
		// know which ones they are in boxen so we forget about them...
		overlaps.length = boxen.length;
		size_t o = 0;
		for (size_t i = 0; i < boxen.length; ++i) {
			auto box = boxen[i];
			if (aabb.overlaps(box))
				overlaps[o++] = i;
		}
		overlaps.length = o;

		return true;
	}

	// Takes ownership of the Array, detaching it.
	// TODO: this function is long, break it up
	void load(
		Array arr,
		Coords* end, Coords target,
		bool binary, bool getAllBeg
	) in {
		assert (end !is null);
	} out {
		if (boxen.length > 0) {
			                     assert (beg.x <= end.x);
			static if (dim >= 2) assert (beg.y <= end.y);
			static if (dim >= 3) assert (beg.z <= end.z);
		}
	} body {
		scope (exit) arr.detach;

		auto input = cast(ubyte[])arr.slice;

		static if (befunge93) {
			assert (target == 0);
			assert (end is &this.end);

			beg  = InitCoords!( 0, 0);
			*end = InitCoords!(79,24);

			auto aabb = AABB(beg, *end);
			aabb.alloc;
			boxen ~= aabb;

			bool gotCR = false;
			auto pos = target;

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

					if (++pos.x >= 80) {
						skipRest: for (++i; i < input.length; ++i) switch (input[i]) {
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
					}
					break;
			}
		} else {
			auto aabb = getAABB(input, binary, target);

			if (aabb.end.x < aabb.beg.x)
				return;

			aabb.finalize;

			                     beg.x = min(beg.x, aabb.beg.x);
			static if (dim >= 2) beg.y = min(beg.y, aabb.beg.y);
			static if (dim >= 3) beg.z = min(beg.z, aabb.beg.z);
			                     end.x = max(end.x, aabb.end.x);
			static if (dim >= 2) end.y = max(end.y, aabb.end.y);
			static if (dim >= 3) end.z = max(end.z, aabb.end.z);

			auto aabbs = placeBox(aabb);

			auto pos = target;

			if (binary) foreach (b; input) {
				if (b != ' ') foreach (box; aabbs) if (box.contains(pos)) {
					box[pos] = cast(cell)b;
					break;
				}
				++pos.x;
			} else {
				static if (dim >= 2) {
					bool gotCR = false;

					void newLine() {
						gotCR = false;
						pos.x = target.x;
						++pos.y;
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
							pos.x = target.x;
							pos.y = target.y;
							++pos.z;
						}
						break;
					case ' ':
						static if (dim >= 2)
							if (gotCR)
								newLine();
						++pos.x;
						break;
					default:
						static if (dim >= 2)
							if (gotCR)
								newLine();

						foreach (box; aabbs) if (box.contains(pos)) {
							box[pos] = cast(cell)b;
							break;
						}
						++pos.x;
						break;
				}
			}
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
		auto beg = InitCoords!(cell.max,cell.max,cell.max);
		auto end = target;

		if (binary) {
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

					if (getBeg) {
						static if (dim >= 3)
						if (getBeg & 0b100 && pos.z < beg.z) {
							beg.z = pos.z;
							getBeg &= ~0b100;
						}
						static if (dim >= 2)
						if (getBeg & 0b010 && pos.y < beg.y) {
							beg.y = pos.y;
							getBeg &= ~0b010;
						}
						if (getBeg & 0b001 && pos.x < beg.x) {
							beg.x = pos.x;
							getBeg &= ~0b001;
						}
					}
				}
				++pos.x;
				break;
		}
		                     end.x = max(lastNonSpace.x, end.x);
		static if (dim >= 2) end.y = max(lastNonSpace.y, end.y);
		static if (dim >= 3) end.z = max(lastNonSpace.z, end.z);

		return AABB.unsafe(beg, end);
	}

	// Currently returns true only when lossage is so small that it's cheaper to
	// subsume than to create a new box, space-wise.
	//
	// Should probably also have some kind of "acceptable number of wasted
	// cells".
	bool subsumeDisjoint(AABB b, AABB fodder, size_t usedCells) {
		return
			cell.sizeof * (b.size - usedCells)
			< cell.sizeof * fodder.data.length + AABB.sizeof;
	}
	// TODO: Eat overlappers if it's worth it
	bool subsumeOverlapping(size_t[] overlaps, AABB b)
	in {
		foreach (i; overlaps)
			assert (boxen[i].overlaps(b));
	} body {
		return false;
	}

	// TODO: Decompose when we would waste too much space іn a new AABB
	bool decompose(size_t[] overlaps, AABB b)
	in {
		foreach (i; overlaps)
			assert (boxen[i].overlaps(b));
	} body {
		return false;
	}

	// Outputs space in the range [beg,end).
	// Puts form feeds / line breaks only between rects/lines.
	// Doesn't trim trailing spaces or anything like that.
	// Doesn't close the given OutputStream.
	void binaryPut(OutputStream file, Coords!(3) beg, Coords!(3) end) {
		scope tfile = new TypedOutput!(ubyte)(file);
		scope (exit) tfile.flush;

		Coords c;
		ubyte b = void;
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
}

// Functions that don't need to live in FungeSpace
private:

// Finds the bounds of the tightest AABB containing all the boxen referred by
// indices, as well as the largest box among them, and keeps a running sum of
// their lengths.
//
// Assumes they're all allocated and max isn't.
void minMaxSize(cell dim)
	(AABB!(dim)[] boxen,
	 ref Coords!(dim) beg, ref Coords!(dim) end,
	 ref size_t max, ref size_t maxSize,
	 ref size_t length,
	 size_t[] indices)
{
	foreach (i; indices)
		minMaxSize!(dim)(boxen, beg, end, max, maxSize, length, i);
}

void minMaxSize(cell dim)
	(AABB!(dim)[] boxen,
	 ref Coords!(dim) beg, ref Coords!(dim) end,
	 ref size_t max, ref size_t maxSize,
	 ref size_t length,
	 size_t i)
{
	auto box = boxen[i];
	length += box.data.length;
	if (box.data.length > maxSize) {
		maxSize = box.data.length;
		max = i;
	}
	                       if (box.beg.x < beg.x) beg.x = box.beg.x;
	                       if (box.end.x > end.x) end.x = box.end.x;
	static if (dim >= 2) { if (box.beg.y < beg.y) beg.y = box.beg.y;
	                       if (box.end.y > end.y) end.y = box.end.y; }
	static if (dim >= 3) { if (box.beg.z < beg.z) beg.z = box.beg.z;
	                       if (box.end.z > end.z) end.z = box.end.z; }
}
