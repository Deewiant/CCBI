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
	// TODO: cleanup
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
		static if (dim == 1) {
			if (this.overlaps(box)) {
				overlap = AABB(
					Coords(max(beg.x, box.beg.x)),
					Coords(min(end.x, box.end.x)));
				return true;
			} else
				return false;

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

			void tryIntersect(Coords p1, Coords p2) {
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
				if (p1.x != p2.x) {
					// x
					if (p1.x < p2.x) { b = p1.x; e = p2.x; }
					else             { b = p2.x; e = p1.x; }

					if (p1.y < box.beg.y || p1.y > box.end.y) return;

					switch (intersect1D(b, e, box.beg.x, box.end.x)) {
						case 2: addPoint(Coords(box.beg.x, p1.y));
						case 1: addPoint(Coords(box.end.x, p1.y)); break;
						case 0: addPoint(Coords(box.beg.x, p1.y)); break;
						default: return;
					}
				} else {
					// y
					if (p1.y < p2.y) { b = p1.y; e = p2.y; }
					else             { b = p2.y; e = p1.y; }

					if (p1.x < box.beg.x || p1.x > box.end.x) return;

					switch (intersect1D(b, e, box.beg.y, box.end.y)) {
						case 2: addPoint(Coords(p1.x, box.beg.y));
						case 1: addPoint(Coords(p1.x, box.end.y)); break;
						case 0: addPoint(Coords(p1.x, box.beg.y)); break;
						default: return;
					}
				}

				intersected = true;
			}

			auto ne = Coords(end.x, beg.y);
			auto sw = Coords(beg.x, end.y);
			auto prev = sw;
			auto prevContained = box.contains(prev);

			foreach (pt; [beg, ne, end, sw]) {
				bool contained = box.contains(pt);
				if (contained)
					addPoint(pt);
				if (!prevContained || !contained)
					tryIntersect(prev, pt);

				prev = pt;
				prevContained = contained;
			}

			if (intersected)
				overlap = AABB(overBeg, overEnd);
			return intersected;

		} else static if (dim == 3) {
			auto
				overBeg = Coords(cell.max, cell.max, cell.max),
				overEnd = Coords(cell.min, cell.min, cell.min);

			void addPoint(Coords p) {
				     if (p.x < overBeg.x) overBeg.x = p.x;
				else if (p.x > overEnd.x) overEnd.x = p.x;
				     if (p.y < overBeg.y) overBeg.y = p.y;
				else if (p.y > overEnd.y) overEnd.y = p.y;
				     if (p.z < overBeg.z) overBeg.z = p.z;
				else if (p.z > overEnd.z) overEnd.z = p.z;
			}

			bool intersected = false;

			void tryIntersect(Coords p1, Coords p2) {
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

				// p1-p2 is axis-aligned: x, y, or z?
				if (p1.x != p2.x) {
					// x
					assert (p1.y == p2.y);
					assert (p1.z == p2.z);

					if (p1.y < box.beg.y || p1.y > box.end.y) return;
					if (p1.z < box.beg.z || p1.z > box.end.z) return;

					if (p1.x < p2.x) { b = p1.x; e = p2.x; }
					else             { b = p2.x; e = p1.x; }

					switch (intersect1D(b, e, box.beg.x, box.end.x)) {
						case 2: addPoint(Coords(box.beg.x, p1.y, p1.z));
						case 1: addPoint(Coords(box.end.x, p1.y, p1.z)); break;
						case 0: addPoint(Coords(box.beg.x, p1.y, p1.z)); break;
						default: return;
					}
				} else if (p1.y != p2.y) {
					// y
					assert (p1.x == p2.x);
					assert (p1.z == p2.z);

					if (p1.x < box.beg.x || p1.x > box.end.x) return;
					if (p1.z < box.beg.z || p1.z > box.end.z) return;

					if (p1.y < p2.y) { b = p1.y; e = p2.y; }
					else             { b = p2.y; e = p1.y; }

					switch (intersect1D(b, e, box.beg.y, box.end.y)) {
						case 2: addPoint(Coords(p1.x, box.beg.y, p1.z));
						case 1: addPoint(Coords(p1.x, box.end.y, p1.z)); break;
						case 0: addPoint(Coords(p1.x, box.beg.y, p1.z)); break;
						default: return;
					}
				} else {
					// z
					assert (p1.x == p2.x);
					assert (p1.y == p2.y);

					if (p1.x < box.beg.x || p1.x > box.end.x) return;
					if (p1.y < box.beg.y || p1.y > box.end.y) return;

					if (p1.z < p2.z) { b = p1.z; e = p2.z; }
					else             { b = p2.z; e = p1.z; }

					switch (intersect1D(b, e, box.beg.z, box.end.z)) {
						case 2: addPoint(Coords(p1.x, p1.y, box.beg.z));
						case 1: addPoint(Coords(p1.x, p1.y, box.end.z)); break;
						case 0: addPoint(Coords(p1.x, p1.y, box.beg.z)); break;
						default: return;
					}
				}

				intersected = true;
			}

			Coords[2][12] edges;
			edges[ 0][0] = beg;         edges[ 0][1] = Coords(end.x,beg.y,beg.z);
			edges[ 1][0] = beg;         edges[ 1][1] = Coords(beg.x,end.y,beg.z);
			edges[ 2][0] = beg;         edges[ 2][1] = Coords(beg.x,beg.y,end.z);
			edges[ 3][0] = end;         edges[ 3][1] = Coords(beg.x,end.y,end.z);
			edges[ 4][0] = end;         edges[ 4][1] = Coords(end.x,beg.y,end.z);
			edges[ 5][0] = end;         edges[ 5][1] = Coords(end.x,end.y,beg.z);
			edges[ 6][0] = edges[0][1]; edges[ 6][1] = edges[4][1];
			edges[ 7][0] = edges[0][1]; edges[ 7][1] = edges[5][1];
			edges[ 8][0] = edges[2][1]; edges[ 8][1] = edges[4][1];
			edges[ 9][0] = edges[2][1]; edges[ 9][1] = edges[3][1];
			edges[10][0] = edges[1][1]; edges[10][1] = edges[5][1];
			edges[11][0] = edges[1][1]; edges[11][1] = edges[3][1];

			foreach (edge; edges) {
				bool a = false, b = false;
				if (box.contains(edge[0])) { addPoint(edge[0]); a = true; }
				if (box.contains(edge[1])) { addPoint(edge[1]); b = true; }
				if (!a || !b)
					tryIntersect(edge[0], edge[1]);
			}

			if (intersected)
				overlap = AABB(overBeg, overEnd);
			return intersected;
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
			if (oldIdx < oldLength) {
				memmove(&data[oldIdx], data.ptr, oldLength * cell.sizeof);
				data[0..oldIdx] = ' ';
			} else {
				data[oldIdx..oldIdx + oldLength] = data[0..oldLength];
				data[0..oldLength] = ' ';
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

					// When the copies are overlapping, the area to be spaced only
					// occurs here, at the last iteration
					//
					// I can't prove this but it makes some sort of sense and seems
					// to be that way.
					if (i <= iend)
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

						if (k <= kend)
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

	private const
		// Completely arbitrary
		NEWBOX_PAD = 8,

		// Fairly arbitrary... A box 5 units wide, otherwise of size NEWBOX_PAD.
		ACCEPTABLE_WASTE = Power!(size_t, NEWBOX_PAD, dim-1) * 5;

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

	size_t boxCount() { return boxen.length; }

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
		++stats.space.lookups;

		foreach (aabb; boxen)
			if (aabb.contains(c))
				return aabb[c];
		return ' ';
	}
	cell opIndexAssign(cell v, Coords c) {
		++stats.space.assignments;

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
		foreach (box; boxen) if (box.contains(aabb)) {
			++stats.space.boxesIncorporated;
			return [box];
		}

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

		// Find any remaining overlaps
		auto overlaps = candidates;
		size_t os = 0;
		for (size_t i = 0; i < overlaps.length; ++i) {
			auto o = overlaps[i];
			if (eater.overlaps(boxen[o]))
				overlaps[os++] = o;
		}

		// Copy overlaps into ret now, since the indices are invalidated if we
		// subsume anything
		AABB[] ret;
		if (os) {
			ret = new AABB[os + 1];
			foreach (i, o; overlaps[0..os])
				ret[i] = boxen[o];
		} else
			ret = new AABB[1];

		if (s)
			aabb = consumeSubsume!(dim)(boxen, subsumes[0..s], food, eater);
		else
			aabb.alloc;

		boxen ~= aabb;
		ret[$-1] = aabb;
		stats.newMax(stats.space.maxBoxesLive, boxen.length);
		return ret;
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
			return cheaperToAlloc(b.size, usedCells + fodder.data.length);
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
				b.size, usedCells + fodder.data.length - overSize);
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
	length += box.data.length;
	if (box.data.length > maxSize) {
		maxSize = box.data.length;
		max = i;
	}
	if (beg) {
		                     if (box.beg.x < beg.x) beg.x = box.beg.x;
		static if (dim >= 2) if (box.beg.y < beg.y) beg.y = box.beg.y;
		static if (dim >= 3) if (box.beg.z < beg.z) beg.z = box.beg.z;
	}
	if (end) {
		                     if (box.end.x > end.x) end.x = box.end.x;
		static if (dim >= 2) if (box.end.y > end.y) end.y = box.end.y;
		static if (dim >= 3) if (box.end.z > end.z) end.z = box.end.z;
	}
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

	foreach (i; subsumes)
		if (i != food)
			aabb.subsume(boxen[i]);

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
