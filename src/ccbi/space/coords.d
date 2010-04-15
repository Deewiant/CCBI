// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2009-09-20 12:03:08

module ccbi.space.coords;

import tango.text.convert.Integer : format;

public import ccbi.cell;
       import ccbi.stdlib : clampedAdd, clampedSub;
       import ccbi.templateutils;

struct Coords(cell dim) {
	static assert (dim >= 1 && dim <= 3);

	union {
		align (1) struct {
			                       cell x;
			static if (dim >= 2) { cell y; }
			static if (dim >= 3) { cell z; }
		}
		// Unfortunately some performance-sensitive operations on this have to be
		// unrolled manually, so we can't use it as much as we'd like.
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

	int opEquals(cell c) {
		                     if (x != c) return false;
		static if (dim >= 2) if (y != c) return false;
		static if (dim >= 3) if (z != c) return false;
		return true;
	}
	int opEquals(Coords c) { return v == c.v; }

	void maxWith(Coords c) {
		                     if (c.x > x) x = c.x;
		static if (dim >= 2) if (c.y > y) y = c.y;
		static if (dim >= 3) if (c.z > z) z = c.z;
	}
	void minWith(Coords c) {
		                     if (c.x < x) x = c.x;
		static if (dim >= 2) if (c.y < y) y = c.y;
		static if (dim >= 3) if (c.z < z) z = c.z;
	}

	template Ops(T...) {
		static assert (T.length != 1);

		static if (T.length == 0)
			const Ops = "";
		else
			// Unrolling these isn't worth it
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

	Coords clampedAdd(cell c) {
		Coords co = *this;
		foreach (inout x; co.v)
			x = .clampedAdd(x, c);
		return co;
	}
	Coords clampedSub(cell c) {
		Coords co = *this;
		foreach (inout x; co.v)
			x = .clampedSub(x, c);
		return co;
	}
}
