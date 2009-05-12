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
		data = new typeof(data)(size);
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

		foreach (aabb; placeBox(AABB(c - NEWBOX_PAD, c + NEWBOX_PAD)))
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

	AABB[] placeBox(AABB aabb)
	out (aabbs) {
		size_t prev = boxen.length;

		// Everything in the return value should be in the same relative order as
		// in boxen (and should be contained in boxen)
		foreach_reverse (box1; aabbs) {
			size_t boxenIdx = boxen.length;

			foreach (j, box2; boxen) if (box1 == box2) {
				boxenIdx = j;
				break;
			}

			assert (boxenIdx < prev);
			prev = boxenIdx;
		}
	} body {
		auto overlapsWith = new AABB[boxen.length];

		size_t j = 0;
		for (size_t i = 0; i < boxen.length; ++i)
			if (aabb.overlaps(boxen[i]))
				overlapsWith[j++] = boxen[i];

		if (j) {
			overlapsWith.length = j;
			auto old = overlapsWith[0];

			if (overlapsWith.length == 1 && old.contains(aabb))
				aabb = old;
			else if (auto resized = resizing(overlapsWith, aabb)) {
				// resized.resizeToContain(aabb);
				aabb = *resized;
				assert (false, "FIXME");

			} else if (decomposing(overlapsWith, aabb)) {
				assert (false, "FIXME");
				// FIXME
				// We can have an arbitrary number of overlaps, so this is
				// more tricky than it seemed
				//auto aabbs = aabb.decomposeByOverlapWith(*old);
				//return aabbs;
			} else {
				aabb.alloc;
				boxen ~= aabb;

				overlapsWith ~= aabb;
				return overlapsWith;
			}
		} else {
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
	AABB* resizing(AABB[] overlaps, AABB b)
	in {
		foreach (old; overlaps)
			assert (old.overlaps(b));
	} body {
		return null;
	}

	// TODO: Decompose when we would waste too much space іn a new AABB
	bool decomposing(AABB[] overlaps, AABB b)
	in {
		foreach (old; overlaps)
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
