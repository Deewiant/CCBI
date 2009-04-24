// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2006-06-09 17:34:29

// Funge-Space and the Coords struct.
module ccbi.space;

import tango.io.model.IConduit;
import tango.io.stream.Typed;
import tango.text.convert.Integer;

public import ccbi.cell;
       import ccbi.templateutils;
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

	template OpAssigns(T...) {
		static assert (T.length != 1);

		static if (T.length == 0)
			const char[] OpAssigns = "";
		else
			const char[] OpAssigns =
				"void op" ~T[0]~ "Assign(cell c) {
					                     x "~T[1]~"= c;
					static if (dim >= 2) y "~T[1]~"= c;
					static if (dim >= 3) z "~T[1]~"= c;
				}

				void op" ~T[0]~ "Assign(Coords c) {
					                     x "~T[1]~"= c.x;
					static if (dim >= 2) y "~T[1]~"= c.y;
					static if (dim >= 3) z "~T[1]~"= c.z;
				}"
				~ OpAssigns!(T[2..$]);
	}

	mixin (OpAssigns!(
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

final class FungeSpace(cell dim) {
	static assert (dim >= 1 && dim <= 3);

	alias .Coords   !(dim) Coords;
	alias .Dimension!(dim).Coords InitCoords;

	this(InputStream source) {
		load(source, &end, InitCoords!(0), false, false);
		lastVal = space[lastCoords = InitCoords!(0)];
	}

	this(FungeSpace other) {
		shallowCopy(this, other);

		// deep copy space
		this.space = null;
		foreach (k, v; other.space)
			this.space[k] = v;
	}

	bool exists(Coords c) {
		return (c in space) !is null;
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

	// most of the time we want range checking, unsafeGet is separate
	cell opIndex(Coords c) {
		cell* p = c in space;
		return p ? *p : ' ';
	}
	cell opIndexAssign(cell v, Coords c) {
		if (c == lastCoords) {
			assert (c in space);
			lastVal = v;
		}

		auto p = c in space;

		if (v != ' ')
			growBegEnd(c);
		else if (p && *p != ' ')
			shrinkBegEnd(c);

		// TODO measure: this might be faster without the if, always doing the
		// latter
		if (p)
			return *p = v;
		else
			return space[c] = v;
	}

	cell unsafeGet(Coords c) {
		if (c != lastCoords)
			lastVal = space[lastCoords = c];
		return lastVal;
	}

	// these are array indices, starting from 0
	// thus the in-use map size is (endX - begX + 1) * (endY - begY + 1)
	// beg.y and beg.z must start at 0 or the first row of the program loops
	// infinitely
	// but beg.x has to be found out: make it doable with less than -checks
	Coords
		beg = Dimension!(dim).Coords!(cell.max),
		end = void;

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

	void shrinkBegEnd(Coords c) {
		// TODO
	}

	// cache the last get, speeds up most programs
	private Coords lastCoords;
	private cell   lastVal;

	private cell[Coords] space;

	// Takes ownership of the InputStream, closing it.
	void load(
		InputStream fc,
		Coords* end, Coords target,
		bool binary, bool getAllBeg
	) in {
		assert (end !is null);
	} body {
		scope file = new TypedInput!(ubyte)(fc);
		scope (exit) { file.close; fc.close; }

		auto pos = target;
		bool gotCR = false;

		// Since we start with a delta of (1,0,0) we can assume beg.y = beg.z = 0
		// when first loading the file.
		// (If that's not the case, we never execute any instructions!)
		int getBegInit = getAllBeg ? 0b111 : 0b100;
		int getBeg = getBegInit;

		// we never actually use the lowest bit of getEnd
		int getEnd = 0b111;

		if (binary) foreach (ubyte b; file) {
			if (b != ' ') {
				if (getBeg && pos.x < beg.x) {
					beg.x = pos.x;
					getBeg = 0;
				} else if (pos.x > end.x)
					end.x = pos.x;

				space[pos] = cast(cell)b;
			}
			++pos.x;
		} else foreach (ubyte b; file)
			loadOne(&pos, b, end, target, &gotCR, &getBeg, getBegInit, &getEnd);
	}

	private void loadOne(
		Coords* pos, ubyte b,
		Coords* end, Coords target,
		bool* gotCR,
		int* getBeg, int initialGetBeg,
		int* getEnd
	) {
		switch (b) {
			case '\r':
				static if (dim >= 2)
					*gotCR = true;
				break;
			case '\f':
				static if (dim >= 3) {
					pos.x = target.x;
					pos.y = target.y;
					++pos.z;
					*gotCR = false;
					*getBeg = initialGetBeg;
					*getEnd |= 0b100;
				}
				break;
			default:
				if (*gotCR) {
			case '\n':
					static if (dim >= 2) {
						pos.x = target.x;
						++pos.y;
						*gotCR = false;
						*getBeg = initialGetBeg;
						*getEnd |= 0b010;
					}

					if (b == '\n')
						break;
				}
				if (b != ' ') {
					if (*getBeg) {
						static if (dim >= 3) if (*getBeg & 0b100 && pos.z < beg.z) {
							beg.z = pos.z;
							*getBeg &= ~0b100;
						}
						static if (dim >= 2) if (*getBeg & 0b010 && pos.y < beg.y) {
							beg.y = pos.y;
							*getBeg &= ~0b010;
						}
						                     if (*getBeg & 0b001 && pos.x < beg.x) {
							beg.x = pos.x;
							*getBeg &= ~0b001;
						}
					}
					if (*getEnd) {
						static if (dim >= 3) if (*getEnd & 0b100 && pos.z > end.z) {
							end.z = pos.z;
							*getEnd &= ~0b100;
						}
						static if (dim >= 2) if (*getEnd & 0b010 && pos.y > end.y) {
							end.y = pos.y;
							*getEnd &= ~0b010;
						}
					}
					if (pos.x > end.x)
						end.x = pos.x;
					space[*pos] = cast(cell)b;
				}
				++pos.x;
				break;
		}
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
		for (cell z = beg.z; z < end.z; ++z) {

			static if (dim >= 3) c.z = z;

			for (cell y = beg.y; y < end.y; ++y) {

				static if (dim >= 2) c.y = y;

				for (cell x = beg.x; x < end.x; ++x) {
					c.x = x;
					b = this[c];
					tfile.write(b);
				}
				if (y != end.y) foreach (ch; NewlineString) {
					b = ch;
					tfile.write(b);
				}
			}

			if (z != end.z) {
				b = '\f';
				tfile.write(b);
			}
		}
	}
}
