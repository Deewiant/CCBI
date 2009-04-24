// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:09:22

module ccbi.fingerprints.cats_eye.toys;

import ccbi.fingerprint;

// 0x544f5953: TOYS
// Funge-98 Standard Toys
// ----------------------

mixin (Fingerprint!(
	"TOYS",

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
	                     	if (d.x < 0) return reverse;

		Coords!(3) de = d.extend(1);`;
}

void bracelet() {
	mixin (PopThree!());

	for (auto z = 0; z < de.z; ++z) {
		for (auto y = 0; y < de.y; ++y) {
			for (auto x = 0; x < de.x; ++x, ++t.x, ++o.x)
				space[t] = space[o];

			t.x -= de.x;
			o.x -= de.x;
			static if (dim >= 2) {
				++t.y;
				++o.y;
			}
		}
		static if (dim >= 2) {
			t.y -= de.y;
			o.y -= de.y;
		}
		static if (dim >= 3) {
			++t.z;
			++o.z;
		}
	}
}
void scissors() {
	mixin (PopThree!());

	t += d;
	o += d;

	for (auto z = de.z; z--;) {
		static if (dim >= 3) {
			--t.z;
			--o.z;
		}
		for (auto y = de.y; y--;) {
			static if (dim >= 2) {
				--t.y;
				--o.y;
			}

			for (auto x = de.x; x--;) {
				--t.x;
				--o.x;
				space[t] = space[o];
			}

			t.x += de.x;
			o.x += de.x;
		}
		static if (dim >= 2) {
			t.y += de.y;
			o.y += de.y;
		}
	}
}
void kittycat() {
	mixin (PopThree!());

	for (auto z = 0; z < de.z; ++z) {
		for (auto y = 0; y < de.y; ++y) {
			for (auto x = 0; x < de.x; ++x, ++t.x, ++o.x) {
				space[t] = space[o];
				space[o] = ' ';
			}

			t.x -= de.x;
			o.x -= de.x;
			static if (dim >= 2) {
				++t.y;
				++o.y;
			}
		}
		static if (dim >= 2) {
			t.y -= de.y;
			o.y -= de.y;
		}
		static if (dim >= 3) {
			++t.z;
			++o.z;
		}
	}
}
void dixiecup() {
	mixin (PopThree!());

	t += d;
	o += d;

	for (auto z = de.z; z--;) {
		static if (dim >= 3) {
			--t.z;
			--o.z;
		}
		for (auto y = de.y; y--;) {
			static if (dim >= 2) {
				--t.y;
				--o.y;
			}

			for (auto x = de.x; x--;) {
				--t.x;
				--o.x;
				space[t] = space[o];
				space[o] = ' ';
			}

			t.x += de.x;
			o.x += de.x;
		}
		static if (dim >= 2) {
			t.y += de.y;
			o.y += de.y;
		}
	}
}

void chicane() {
	Coords!(3) a = popOffsetVector().extend(1);
	Coords!(3) b = popVector      ().extend(1);
	b += a;

	cell val = cip.stack.pop;

	Coords c = void;
	static if (dim >= 3) {
		for (c.z = a.z; c.z < b.z; ++c.z)
			for (c.y = a.y; c.y < b.y; ++c.y)
				for (c.x = a.x; c.x < b.x; ++c.x)
					space[c] = val;

	} else static if (dim == 2) {
		for (c.y = a.y; c.y < b.y; ++c.y)
			for (c.x = a.x; c.x < b.x; ++c.x)
				space[c] = val;

	} else
		for (c.x = a.x; c.x < b.x; ++c.x)
			space[c] = val;
}

void fishhook() {
	static if (dim < 2)
		reverse;
	else {
		auto n = cip.stack.pop;

		Coords c  = cip.pos;
		Coords c2 = c;

		if (n < 0) {
			c.y = space.beg.y;
			c2.y = c.y + n;
			for (auto oldEnd = space.end.y; c.y <= oldEnd; ++c.y, ++c2.y)
				space[c2] = space[c];

		} else if (n > 0) {
			c.y = space.end.y;
			c2.y = c.y + n;
			for (auto oldBeg = space.beg.y; c.y >= oldBeg; --c.y, --c2.y)
				space[c2] = space[c];
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

		if (n < 0) {
			c.x = space.beg.x;
			c2.x = c.x + n;
			for (auto oldEnd = space.end.x; c.x <= oldEnd; ++c.x, ++c2.x)
				space[c2] = space[c];

		} else if (n > 0) {
			c.x = space.end.x;
			c2.x = c.x + n;
			for (auto oldBeg = space.beg.x; c.x >= oldBeg; --c.x, --c2.x)
				space[c2] = space[c];
		}
	}
}

void corner() {
	static if (dim < 2)
		reverse;
	else {
		Coords p = cip.pos, d = cip.delta;

		turnLeft();
		cip.move();
		cip.stack.push(space[cip.pos]);

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

		turnRight();
		cip.move();
		cip.stack.push(space[cip.pos]);

		cip.pos   = p;
		cip.delta = d;
	}
}

// doric column
void doricColumn() { with (cip.stack) push(pop + cast(cell)1); }

// toilet seat
void toiletSeat()  { with (cip.stack) push(pop - cast(cell)1); }

// lightning bolt
void lightningBolt() { with (cip.stack) push(-pop); }

// pair of stilts
void pairOfStilts() {
	with (cip.stack) {
		cell b = pop,
		     a = pop;

		if (b < 0)
			push(a >> (-b));
		else
			push(a << b);
	}
}

void gable() {
	with (cip.stack) for (cell n = pop, c = pop; n--;)
		push(c);
}

// pair of shoes
void pairOfShoes() {
	with (cip.stack) {
		auto y = pop, x = pop;
		push(x+y, x-y);
	}
}

// pitchfork head
void pitchforkHead() {
	cell sum = 0;
	foreach (c; cip.stack)
		sum += c;
	cip.stack.clear;
	cip.stack.push(sum);
}

void mailbox() {
	cell prod = 1;
	foreach (c; cip.stack)
		prod *= c;
	cip.stack.clear;
	cip.stack.push(prod);
}

void calipers() {
	cell i, j;

	Coords t = popOffsetVector();

	with (cip.stack) {
		// j's location not in spec...
		j = pop;
		i = pop;

		Coords c = t;

		for (c.y = t.y; c.y < t.y + j; ++c.y)
		for (c.x = t.x; c.x < t.x + i; ++c.x)
			space[c] = pop;
	}
}
void counterclockwise() {
	cell i, j;

	Coords o = popOffsetVector();

	with (cip.stack) {
		// j's location not in spec...
		j = pop;
		i = pop;

		Coords c = o;

		for (c.y = o.y + j; c.y-- > o.y;)
		for (c.x = o.x + i; c.x-- > o.x;)
			push(space[c]);
	}
}

void necklace() {
	with (cip) space[pos - delta] = stack.pop;
}

void barstool() {
	// TODO: befunge-only
	switch (cip.stack.pop) {
		case 0: eastWestIf(); break;
		case 1: northSouthIf(); break;
		default: reverse(); break;
	}
}

void tumbler() {
	// TODO: befunge-only
	switch (rand_up_to!(4)()) {
		case 0: space[cip.pos] = '<'; goWest (); break;
		case 1: space[cip.pos] = '>'; goEast (); break;
		case 2: space[cip.pos] = 'v'; goSouth(); break;
		case 3: space[cip.pos] = '^'; goNorth(); break;
		default: assert (false);
	}
}

// television antenna
void televisionAntenna() {
	Coords c = popOffsetVector();

	auto
		v = cip.stack.pop,
		x = space[c];

	if (x < v) {
		cip.stack.push(v);
		pushOffsetVector(c);
		cip.pos -= cip.delta;
	} else if (x > v)
		reverse();
}

// buried treasure
void buriedTreasure() {                      ++cip.pos.x; }
void slingshot()      { static if (dim >= 2) ++cip.pos.y; else reverse; }

// barn door
void barnDoor()       { static if (dim >= 3) ++cip.pos.z; else reverse; }

}
