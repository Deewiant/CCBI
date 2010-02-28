// File created: 2009-09-20 12:03:08

module ccbi.space.coords;

import tango.text.convert.Integer : format;

public import ccbi.cell;
       import ccbi.templateutils;

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

	template Any(char[] s, char[] op) {
		const Any =
			`bool any` ~s~ `(Coords o) {
				foreach (i, c; v)
					if (c ` ~op~ ` o.v[i])
						return true;
				return false;
			}`;
	}
	mixin (Any!("Less",    "<"));
	mixin (Any!("Greater", ">"));
}