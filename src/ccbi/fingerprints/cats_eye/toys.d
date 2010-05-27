// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2007-01-20 21:09:22

module ccbi.fingerprints.cats_eye.toys;

import ccbi.fingerprint;

mixin (Fingerprint!(
	"TOYS",
	`Funge-98 Standard Toys

      'B' pops y, then x, and pushes x+y, then x-y. This may or may not be the
          the "butterfly bit operation" requested.

      'H' performs a signed right shift.

      'T' reverses if the dimension number is too big or small.

      'Z' reverses outside Trefunge.`\n,

	"A", "gable",
	"B", "pairOfShoes",
	"C", "bracelet",
	"D", "toiletSeat",
	"E", "pitchforkHead",
	"F", "calipers",
	"G", "counterclockwise",
	"H", "pairOfStilts",
	"I", "doricColumn",
	"J", "fishhook",
	"K", "scissors",
	"L", "corner",
	"M", "kittycat",
	"N", "lightningBolt",
	"O", "boulder",
	"P", "mailbox",
	"Q", "necklace",
	"R", "canOpener",
	"S", "chicane",
	"T", "barstool",
	"U", "tumbler",
	"V", "dixiecup",
	"W", "televisionAntenna",
	"X", "buriedTreasure",
	"Y", "slingshot",
	"Z", "barnDoor"
));

template TOYS() {

template PopThree() {
	const PopThree = `
		Coords t = popOffsetVector();
		Coords d = popVector();
		Coords o = popOffsetVector();

		if (d == 0)
			return;

		// Undefined behaviour...
		//
		// Could do something tricky here like mirror and flip the area copied or
		// then just do a normal copy from o-d to o
		//
		// But nah, most likely it's user error
		static if (dim >= 3) if (d.z < 0) return reverse;
		static if (dim >= 2) if (d.y < 0) return reverse;
		                     if (d.x < 0) return reverse;`;
}

void bracelet() {
	mixin (PopThree!());

	const char[] X =
		"for (auto x = 0; x < d.x; ++x, ++t.x, ++o.x)"
		"	state.space[t] = state.space[o];";

	const char[] Y =
		"for (auto y = 0; y < d.y; ++y) {"
		"	" ~X~
		"	t.x -= d.x;"
		"	o.x -= d.x;"
		"	++t.y;"
		"	++o.y;"
		"}";

	static if (dim == 3) {
		for (auto z = 0; z < d.z; ++z) {

			mixin (Y);

			t.y -= d.y;
			o.y -= d.y;
			++t.z;
			++o.z;
		}
	} else static if (dim == 2)
		mixin (Y);
	else static if (dim == 1)
		mixin (X);
}
void scissors() {
	mixin (PopThree!());

	t += d;
	o += d;

	const char[] X =
		"for (auto x = d.x; x--;) {"
		"	--t.x;"
		"	--o.x;"
		"	state.space[t] = state.space[o];"
		"}";

	const char[] Y =
		"for (auto y = d.y; y--;) {"
		"	--t.y;"
		"	--o.y;"
		"	" ~X~
		"	t.x += d.x;"
		"	o.x += d.x;"
		"}";

	static if (dim == 3) {
		for (auto z = d.z; z--;) {
			--t.z;
			--o.z;
			mixin (Y);
			t.y += d.y;
			o.y += d.y;
		}
	} else static if (dim == 2)
		mixin (Y);
	else static if (dim == 1)
		mixin (X);
}
void kittycat() {
	mixin (PopThree!());

	const char[] X =
		"for (auto x = 0; x < d.x; ++x, ++t.x, ++o.x) {"
		"	state.space[t] = state.space[o];"
		"	state.space[o] = ' ';"
		"}";

	const char[] Y =
		"for (auto y = 0; y < d.y; ++y) {"
		"	" ~X~
		"	t.x -= d.x;"
		"	o.x -= d.x;"
		"	++t.y;"
		"	++o.y;"
		"}";

	static if (dim == 3) {
		for (auto z = 0; z < d.z; ++z) {
			mixin (Y);
			t.y -= d.y;
			o.y -= d.y;
			++t.z;
			++o.z;
		}
	} else static if (dim == 2)
		mixin (Y);
	else static if (dim == 1)
		mixin (X);
}
void dixiecup() {
	mixin (PopThree!());

	t += d;
	o += d;

	const char[] X =
		"for (auto x = d.x; x--;) {"
		"	--t.x;"
		"	--o.x;"
		"	state.space[t] = state.space[o];"
		"	state.space[o] = ' ';"
		"}";

	const char[] Y =
		"for (auto y = d.y; y--;) {"
		"	--t.y;"
		"	--o.y;"
		"	" ~X~
		"	t.x += d.x;"
		"	o.x += d.x;"
		"}";

	static if (dim == 3) {
		for (auto z = d.z; z--;) {
			--t.z;
			--o.z;
			mixin (Y);
			t.y += d.y;
			o.y += d.y;
		}
	} else static if (dim == 2)
		mixin (Y);
	else static if (dim == 1)
		mixin (X);
}

void chicane() {
	Coords a = popOffsetVector();
	Coords b = popVector      ();

	cell val = cip.stack.pop;

	auto f = (cell[] arr, ref Stat, ref Stat w) {
		arr[] = val;
		w += arr.length;
	};

	if (val == ' ')
		state.space.mapNoAlloc(a, a+b-1, f);
	else
		state.space.map       (a, a+b-1, f);
}

void fishhook() {
	static if (dim < 2)
		reverse;
	else {
		auto n = cip.stack.pop;

		Coords c  = cip.pos;
		Coords c2 = c;

		Coords beg, end;
		state.space.getLooseBounds(beg, end);

		if (n < 0) {
			c.y = beg.y;
			c2.y = c.y + n;
			for (auto oldEnd = end.y; c.y <= oldEnd; ++c.y, ++c2.y)
				state.space[c2] = state.space[c];

		} else if (n > 0) {
			c.y = end.y;
			c2.y = c.y + n;
			for (auto oldBeg = beg.y; c.y >= oldBeg; --c.y, --c2.y)
				state.space[c2] = state.space[c];
		}
	}
}

void boulder() {
	static if (dim < 2)
		reverse;
	else {
		auto n = cip.stack.pop;

		Coords c  = cip.pos;
		Coords c2 = c;

		Coords beg, end;
		state.space.getLooseBounds(beg, end);

		if (n < 0) {
			c.x = beg.x;
			c2.x = c.x + n;
			for (auto oldEnd = end.x; c.x <= oldEnd; ++c.x, ++c2.x)
				state.space[c2] = state.space[c];

		} else if (n > 0) {
			c.x = end.x;
			c2.x = c.x + n;
			for (auto oldBeg = beg.x; c.x >= oldBeg; --c.x, --c2.x)
				state.space[c2] = state.space[c];
		}
	}
}

void corner() {
	static if (dim < 2)
		reverse;
	else {
		Coords p = cip.pos, d = cip.delta;

		Std.turnLeft();
		cip.move();
		cip.stack.push(cip.cell);

		cip.pos   = p;
		cip.delta = d;
	}
}

// can opener
void canOpener() {
	static if (dim < 2)
		reverse;
	else {
		Coords p = cip.pos, d = cip.delta;

		Std.turnRight();
		cip.move();
		cip.stack.push(cip.cell);

		cip.pos   = p;
		cip.delta = d;
	}
}

// doric column
void doricColumn() { with (*cip.stack) push(pop + 1); }

// toilet seat
void toiletSeat()  { with (*cip.stack) push(pop - 1); }

// lightning bolt
void lightningBolt() { with (*cip.stack) push(-pop); }

// pair of stilts
void pairOfStilts() {
	with (*cip.stack) {
		cell b = pop,
		     a = pop;

		if (b < 0)
			push(a >> (-b));
		else
			push(a << b);
	}
}

void gable() {
	with (*cip.stack) {
		auto n = pop;
		auto c = pop;
		reserve(n)[0..n] = c;
	}
}

// pair of shoes
void pairOfShoes() {
	with (*cip.stack) {
		auto y = pop, x = pop;
		push(x+y, x-y);
	}
}

// pitchfork head
void pitchforkHead() {
	cell sum = 0;
	foreach (c; *cip.stack)
		sum += c;
	cip.stack.clear;
	cip.stack.push(sum);
}

void mailbox() {
	cell prod = 1;
	foreach (c; *cip.stack)
		prod *= c;
	cip.stack.clear;
	cip.stack.push(prod);
}

void calipers() {
	static if (dim >= 2) {
		cell i, j;

		Coords t = popOffsetVector();

		with (*cip.stack) {
			// j's location not in spec...
			j = pop;
			i = pop;

			Coords c = t;

			for (c.y = t.y; c.y < t.y + j; ++c.y)
			for (c.x = t.x; c.x < t.x + i; ++c.x)
				state.space[c] = pop;
		}
	} else reverse;
}
void counterclockwise() {
	static if (dim >= 2) {
		cell i, j;

		Coords o = popOffsetVector();

		with (*cip.stack) {
			// j's location not in spec...
			j = pop;
			i = pop;

			Coords c = o;

			auto p = reserve(i*j);

			version (MODE)
				auto mode = cip.stack.mode;
			else
				const mode = 0;

			if (mode & INVERT_MODE) {
				p += i*j - 1;
				for (c.y = o.y + j; c.y-- > o.y;)
				for (c.x = o.x + i; c.x-- > o.x;)
					*p-- = state.space[c];
			} else
				for (c.y = o.y + j; c.y-- > o.y;)
				for (c.x = o.x + i; c.x-- > o.x;)
					*p++ = state.space[c];
		}
	} else reverse;
}

void necklace() {
	with (*cip) state.space[pos - delta] = stack.pop;
}

void barstool() {
	switch (cip.stack.pop) {
		                    case 0: eastWestIf;   break;
	static if (dim >= 2) { case 1: northSouthIf; break; }
	static if (dim >= 3) { case 2: highLowIf;    break; }
		                    default: reverse;     break;
	}
}

void tumbler() {
	switch (randomUpTo!(uint, 2*dim)()) {
		case 0: cip.unsafeCell = '<'; goWest (); break;
		case 1: cip.unsafeCell = '>'; goEast (); break;
	static if (dim >= 2) {
		case 2: cip.unsafeCell = 'v'; goSouth(); break;
		case 3: cip.unsafeCell = '^'; goNorth(); break;
	}
	static if (dim >= 3) {
		case 4: cip.unsafeCell = 'l'; goLow  (); break;
		case 5: cip.unsafeCell = 'h'; goHigh (); break;
	}
		default: assert (false);
	}
}

// television antenna
void televisionAntenna() {
	Coords c = popOffsetVector();

	auto
		v = cip.stack.pop,
		x = state.space[c];

	if (x < v) {
		cip.stack.push(v);
		pushOffsetVector(c);
		cip.unmove;

	} else if (x > v)
		reverse();
}

// buried treasure
void buriedTreasure() {                      cip.move(InitCoords!(1,0,0)); }
void slingshot()      { static if (dim >= 2) cip.move(InitCoords!(0,1,0)); else reverse; }

// barn door
void barnDoor()       { static if (dim >= 3) cip.move(InitCoords!(0,0,1)); else reverse; }

}
