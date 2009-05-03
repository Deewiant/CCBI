// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2006-06-09 17:34:29

// Funge-Space and the Coords struct.
module ccbi.space;

import tango.io.device.Array      : Array;
import tango.io.model.IConduit    : OutputStream;
import tango.io.stream.Typed      : TypedOutput;
import tango.math.Math            : min, max;
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
					static if (dim >= 3) co.y "~T[1]~"= c;
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
	alias .Coords!(dim) Coords;

	union {
		cell[] data;
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
		AABB aabb;
		with (aabb) {
			beg = b;
			end = e;

			size = e.x - b.x + 1;

			static if (dim >= 2) {
				width = size;
				size *= e.y - b.y + 1;
			}
			static if (dim >= 3) {
				area = size;
				size *= e.z - b.z + 1;
			}
		}
		return aabb;
	}

	void alloc() {
		auto size = size;
		data = null;
		typedef cell initcell = ' ';
		data = cast(cell[])new initcell[size];
	}

	bool contains(Coords p) {
		                     if (!(p.x >= beg.x && p.x <= end.x)) return false;
      static if (dim >= 2) if (!(p.y >= beg.y && p.y <= end.y)) return false;
      static if (dim >= 3) if (!(p.z >= beg.z && p.z <= end.z)) return false;

		return true;
	}
	bool contains(AABB b) {
		return contains(b.beg) && contains(b.end);
	}

	cell opIndex(Coords p)
	in {
		assert (this.contains(p));

		// If alloc hasn't been called, might not be caught
		assert (data !is null);
		assert (getIdx(p) < data.length);
	}
	body {
		return data[getIdx(p)];
	}
	cell opIndexAssign(cell val, Coords p)
	in {
		assert (this.contains(p));

		// Ditto above
		assert (data !is null);
		assert (getIdx(p) < data.length);
	} body {
		return data[getIdx(p)] = val;
	}
	private size_t getIdx(Coords p) {
		p -= beg;

		size_t idx = p.x;

		static if (dim >= 2) idx += width * p.y;
		static if (dim >= 3) idx += area  * p.z;

		return idx;
	}

	bool overlaps(AABB b) {
		if (beg.x <= b.end.x && b.beg.x <= end.x)
			return true;

		static if (dim >= 2)
		if (beg.y <= b.end.y && b.beg.y <= end.y)
			return true;

		static if (dim >= 3)
		if (beg.z <= b.end.z && b.beg.z <= end.z)
			return true;

		return false;
	}

	AABB getOverlapWith(AABB b)
	in {
		assert (this.overlaps(b));
	} body {
		Coords beg, end;
		beg.x = max(this.beg.x, b.beg.x);
		end.x = min(this.end.x, b.end.x);
		static if (dim >= 2) {
			beg.y = max(this.beg.y, b.beg.y);
			end.y = min(this.end.y, b.end.y);
		}
		static if (dim >= 3) {
			beg.z = max(this.beg.z, b.beg.z);
			end.z = min(this.end.z, b.end.z);
		}
		return AABB(beg, end);
	}

	AABB fuseWith(AABB b)
	in {
		assert (!this.overlaps(b));
	} body {
		// This check suffices: they can't be the same or we'd have an overlap or
		// zero-area box.
		if (this.beg.x < b.end.x)
			return AABB(this.beg, b.end);
		else
			return AABB(b.beg, this.end);
	}

	AABB[] decomposeByOverlapWith(AABB b)
	in {
		assert (this.overlaps(b));
	} body {
		auto overlap = this.getOverlapWith(b);

		AABB[Power!(size_t, 3, dim)] subs;

		// {{{ fill subs in a fairly random order
		subs[0] = AABB(b.beg, overlap.beg);
		subs[1] = overlap;
		subs[2] = AABB(overlap.end, b.end);

		static if (dim >= 2) {
			// What we've got now:
			//
			// y
			// |  b.beg +---+--+---+
			// |        | A | h| i |
			// |        +---+--+---+
			// |        | e | B| d |
			// |        +---+--+---+
			// |        | f | g| C |
			// |        +---+--+---+ b.end
			// |
			// +---------------x
			//
			// subs[0] = A
			// subs[1] = B
			// subs[2] = C

			Coords c, d;

			static if (dim >= 3) {
				c.z = b.beg.z;
				d.z = overlap.beg.z;
			}

			c.x = overlap.end.x;
			d.x = b.end.x;
			c.y = overlap.beg.y;
			d.y = overlap.end.y;
			subs[3] = AABB(c, d); // d (east)

			c.x = b.beg.x;
			d.x = overlap.beg.x;
			subs[4] = AABB(c, d); // e (west)

			c.y = overlap.end.y;
			d.y = b.end.y;
			subs[5] = AABB(c, d); // f (southwest)

			c.x = overlap.beg.x;
			d.x = overlap.end.x;
			subs[6] = AABB(c, d); // g (south)

			c.y = b.beg.y;
			d.y = overlap.beg.y;
			subs[7] = AABB(c, d); // h (north)

			c.x = overlap.end.x;
			d.x = b.end.x;
			subs[8] = AABB(c, d); // i (northeast)
		}
		static if (dim >= 3) {
			// What we've got now:
			//
			//                +---+--+---+
			//               / r / s/ t /|
			//              +---+--+---+t+
			//             / j /k / l /|/|
			//            +---+--+---+l+w+
			// y         / A / D/ F /|/|/|
			// |  b.beg +---+--+---+F+n+Z+ b.end
			// |        | A | F| G |/|/|/
			// |        +---+--+---+G+q+
			// |    z   | C | i| B |/|/
			// |   /    +---+--+---+h+
			// |  /     | D | E| h |/
			// | /      +---+--+---+
			// |/
			// +---------------x
			//
			// subs[0] = A
			// subs[1] = centre, invisible in above
			// subs[2] = Z
			// subs[3] = B
			// subs[4] = C
			// subs[5] = D
			// subs[6] = E
			// subs[7] = F
			// subs[8] = G
			//
			// b is the whole cube, overlap is the centre
			// c and d are beg and end of G.

			c.y = overlap.end.y;
			d.y = b.end.y;
			subs[9]  = AABB(c, d); // h (southeast)

			d.x = overlap.beg.x;
			d.y = overlap.beg.y;
			subs[10] = AABB(d, c); // i (middle)

			d.z = overlap.end.z;
			c.z = b.end.z;
			subs[11] = AABB(d, c); // v (rear middle)

			d.y = b.beg.y;
			c.y = overlap.beg.y;
			subs[12] = AABB(d, c); // s (rear north)

			d.y = overlap.end.y;
			c.y = b.end.y;
			subs[13] = AABB(d, c); // y (rear south)

			d.x = b.beg.x;
			c.x = overlap.beg.x;
			subs[14] = AABB(d, c); // x (rear southwest)

			d.y = overlap.beg.y;
			c.y = overlap.end.y;
			subs[15] = AABB(d, c); // u (rear west)

			d.y = b.beg.y;
			c.y = overlap.beg.y;
			subs[16] = AABB(d, c); // r (rear northwest)

			d.x = overlap.end.x;
			c.x = b.end.x;
			subs[17] = AABB(d, c); // t (rear northeast)

			d.y = overlap.beg.y;
			c.y = overlap.end.y;
			subs[18] = AABB(d, c); // w (rear east)

			d.z = overlap.beg.z;
			c.z = overlap.end.z;
			subs[19] = AABB(d, c); // n (mid east)

			d.y = overlap.end.y;
			c.y = b.end.y;
			subs[20] = AABB(d, c); // q (mid southeast)

			d.x = overlap.beg.x;
			c.x = overlap.end.x;
			subs[21] = AABB(d, c); // p (mid south)

			d.x = b.beg.x;
			c.x = overlap.beg.x;
			subs[22] = AABB(d, c); // o (mid southwest)

			d.y = overlap.beg.y;
			c.y = overlap.end.y;
			subs[23] = AABB(d, c); // m (mid west)

			d.y = b.beg.y;
			c.y = overlap.beg.y;
			subs[24] = AABB(d, c); // j (mid northwest)

			d.x = overlap.beg.x;
			c.x = overlap.end.x;
			subs[25] = AABB(d, c); // k (mid north)

			d.x = overlap.end.x;
			c.x = b.end.x;
			subs[26] = AABB(d, c); // l (mid northeast)
		}
		// }}}

		AABB*[Power!(size_t, 3, dim)] maybeNonEmpties;

		size_t i = 0;
		foreach (aabb; subs) {
			                     if (aabb.beg.x == aabb.end.x) continue;
			static if (dim >= 2) if (aabb.beg.y == aabb.end.y) continue;
			static if (dim >= 3) if (aabb.beg.z == aabb.end.z) continue;
			maybeNonEmpties[i++] = &aabb;
		}
		auto nonEmpties = maybeNonEmpties[0..i];

		size_t joins = 0;
		for (size_t j = 0; j < nonEmpties.length; ++j) {
			auto b1 = nonEmpties[j];
			if (!b1)
				continue;

			retry:
			for (size_t k = 0; k < nonEmpties.length; ++k) {
				auto b2 = nonEmpties[k];
				if (!b2)
					continue;

				bool join = false;

				if (b1.beg.x == b2.beg.x && b1.end.x == b2.end.x)
					join = true;
				else {
					static if (dim >= 2)
					if (b1.beg.y == b2.beg.y && b1.end.y == b2.end.y)
						join = true;
					else {
						static if (dim >= 3)
						if (b1.beg.z == b2.beg.z && b1.end.z == b2.end.z)
							join = true;
					}
				}

				if (join) {
					*b1 = b1.fuseWith(*b2);
					nonEmpties[k] = null;
					++joins;
					goto retry;
				}
			}
		}

		auto finals = new AABB[nonEmpties.length - joins];
		i = 0;
		foreach (aabb; nonEmpties) if (aabb)
			finals[i++] = *aabb;

		assert (i == finals.length);
		return finals;
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
	// beg.y and beg.z must start at 0, otherwise the program is just an
	// infinite loop.
	//
	// beg.x has to be found out, though: initialize so that it's doable with
	// less-than checks.
	Coords
		beg = InitCoords!(cell.max),
		end = void;

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
		foreach (aabb; boxen)
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

		// New box time
		auto aabbs = placeBox(AABB(c - NEWBOX_PAD, c + NEWBOX_PAD));
		assert (aabbs.length == 1, "FIXME too many boxes");

		return aabbs[0][c] = v;
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

		AABB* overlapsWith = null;
		foreach (b; boxen) if (aabb.overlaps(b)) {
			overlapsWith = &b;
			break;
		}

		if (auto old = overlapsWith) {
			if (old.contains(aabb))
				aabb = *old;

			else if (resizing(*old, aabb)) {
				// old.resizeToContain(aabb);
				aabb = *old;
				assert (false, "FIXME");

			} else if (decomposing(*old, aabb)) {
				auto aabbs = aabb.decomposeByOverlapWith(*old);
				assert (false, "FIXME"); // FIXME
				return aabbs;
			} else
				goto justAlloc;
		} else justAlloc: {
			aabb.alloc;
			boxen ~= aabb;
		}

		static AABB[1] one;
		one[0] = aabb;
		return one;
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

		// Since we start with a delta of (1,0,0) we can assume beg.y = beg.z = 0
		// when first loading.
		// (If that's not the case, we never execute any instructions!)
		ubyte getBegInit = getAllBeg ? 0b111 : 0b001;

		     static if (dim == 1) getBegInit &= 0b001;
		else static if (dim == 2) getBegInit &= 0b011;

		static if (befunge93) {
			assert (target == 0);

			auto aabb = AABB(InitCoords!(0,0), InitCoords!(79,24));
			aabb.alloc;
			boxen ~= aabb;

			// loading can be fairly straightforward copying...
			// befunge93 doesn't even need the bounds, just set them to
			// (80,25).
			// FIXME
			assert (0, "FIXME");

			/+
			size_t i = -1;
			auto pos = target;

			nextRow:
			for (int r = 0; r < 25; ++r) {
				for (int c = 0; c < 80; ++c) {
					if (++i >= input.length)
						return;

					loadOne(
						input[i], &pos, aabb,
						end, target,
						&gotCR, &getBeg, getBegInit, &getEnd);
				}
				if (pos.x != target.x)
				while (++i < input.length) switch (input[i]) {
					case '\r': gotCR = true; break;
					default:
						if (gotCR) {
							--i;
					case '\n':
							pos.x = 0;
							++pos.y;
							gotCR = false;
							getBeg = getBegInit;
							getEnd |= 0b010;
							continue nextRow;
						} else
							break;
				}
			}
			+/
		} else {
			auto aabb = getAABB(input, binary, target, getBegInit);

			if (aabb.end.x < aabb.beg.x)
				return;

			                     beg.x = min(beg.x, aabb.beg.x);
			static if (dim >= 2) beg.y = min(beg.y, aabb.beg.y);
			static if (dim >= 3) beg.z = min(beg.z, aabb.beg.z);
			                     end.x = max(end.x, aabb.end.x);
			static if (dim >= 2) end.y = max(end.y, aabb.end.y);
			static if (dim >= 3) end.z = max(end.z, aabb.end.z);

			auto aabbs = placeBox(aabb);
			aabb = aabbs[0];

			assert (aabbs.length == 1, "FIXME too many boxes");

			auto pos = target;

			if (binary) foreach (b; input) {
				if (b != ' ')
					// FIXME: what if we've got multiple boxes
					aabb[pos] = cast(cell)b;
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

						// FIXME: what if we've got multiple boxes
						aabb[pos] = cast(cell)b;
						++pos.x;
						break;
				}
			}
		}
	}

	// If nothing would be loaded, end.x < beg.x in the return value
	//
	// target: where input is being loaded to
	// initialGetBeg: bit mask of what beg coordinates we're interested in
	//                (0b001 (x) for initial load, 0b111 otherwise)
	AABB getAABB(
		ubyte[] input,
		bool binary,
		Coords target,
		ubyte initialGetBeg)
	{
		Coords beg, end;

		beg = end = target;

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

			return AABB(beg, end);
		}

		auto getBeg = initialGetBeg;
		auto pos = target;
		auto lastNonSpace = end;

		static if (dim >= 2) {
			bool gotCR = false;

			void newLine() {
				end.x = max(lastNonSpace.x, end.x);

				pos.x = target.x;
				++pos.y;
				gotCR = false;
				getBeg = initialGetBeg & 0b001;
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
					getBeg = initialGetBeg & 0b011;
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

		return AABB(beg, end);
	}

	// TODO: Resize when:
	//   a) old aabb is fully contained within new
	//   b) boxes can be joined (as in AABB.decomposeByOverlapWith)
	bool resizing(AABB old, AABB b)
	in {
		assert (old.overlaps(b));
	} body {
		return false;
	}

	// TODO: Decompose when we would waste too much space іn a new AABB
	bool decomposing(AABB old, AABB b)
	in {
		assert (old.overlaps(b));
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
