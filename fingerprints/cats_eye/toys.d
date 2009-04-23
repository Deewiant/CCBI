// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:09:22

module ccbi.fingerprints.cats_eye.toys; private:

import ccbi.fingerprint;
import ccbi.instructions : goWest, goEast, goSouth, goNorth, eastWestIf, northSouthIf, reverse, turnLeft, turnRight;
import ccbi.ip;
import ccbi.random;
import ccbi.space;
import ccbi.utils;

// 0x544f5953: TOYS
// Funge-98 Standard Toys
// ----------------------

static this() {
	mixin (Code!("TOYS"));

	fingerprints[TOYS]['A'] =& gable;
	fingerprints[TOYS]['B'] =& pairOfShoes;
	fingerprints[TOYS]['C'] =& bracelet;
	fingerprints[TOYS]['D'] =& toiletSeat;
	fingerprints[TOYS]['E'] =& pitchforkHead;
	fingerprints[TOYS]['F'] =& calipers;
	fingerprints[TOYS]['G'] =& counterclockwise;
	fingerprints[TOYS]['H'] =& pairOfStilts;
	fingerprints[TOYS]['I'] =& doricColumn;
	fingerprints[TOYS]['J'] =& fishhook;
	fingerprints[TOYS]['K'] =& scissors;
	fingerprints[TOYS]['L'] =& corner;
	fingerprints[TOYS]['M'] =& kittycat;
	fingerprints[TOYS]['N'] =& lightningBolt;
	fingerprints[TOYS]['O'] =& boulder;
	fingerprints[TOYS]['P'] =& mailbox;
	fingerprints[TOYS]['Q'] =& necklace;
	fingerprints[TOYS]['R'] =& canOpener;
	fingerprints[TOYS]['S'] =& chicane;
	fingerprints[TOYS]['T'] =& barstool;
	fingerprints[TOYS]['U'] =& tumbler;
	fingerprints[TOYS]['V'] =& dixiecup;
	fingerprints[TOYS]['W'] =& televisionAntenna;
	fingerprints[TOYS]['X'] =& buriedTreasure;
	fingerprints[TOYS]['Y'] =& slingshot;
	fingerprints[TOYS]['Z'] =& reverse; // 3D only
}

void bracelet() {
	cellidx ox, oy, dx, dy, tx, ty;

	popVector        (tx, ty);
	popVector!(false)(dx, dy);
	popVector        (ox, oy);

	if (!dx || !dy)
		return;

	// undefined behaviour
	// could do something tricky here like mirror and flip the area copied
	// or just do a normal copy from (ox-dx, oy-dy) to (ox, oy)
	// but it's more likely it's an error
	if (dx < 0 || dy < 0) {
		reverse();
		return;
	}

	for (cellidx x = 0; x < dx; ++x)
		for (cellidx y = 0; y < dy; ++y)
			space[tx+x, ty+y] = space[ox+x, oy+y];
}
void scissors() {
	cellidx ox, oy, dx, dy, tx, ty;

	popVector        (tx, ty);
	popVector!(false)(dx, dy);
	popVector        (ox, oy);

	if (!dx || !dy)
		return;

	// see comment in bracelet()
	if (dx < 0 || dy < 0) {
		reverse();
		return;
	}

	for (cellidx x = dx; x--;)
		for (cellidx y = dx; y--;)
			space[tx+x, ty+y] = space[ox+x, oy+y];
}
void kittycat() {
	cellidx ox, oy, dx, dy, tx, ty;

	popVector        (tx, ty);
	popVector!(false)(dx, dy);
	popVector        (ox, oy);

	if (!dx || !dy)
		return;

	// see comment in bracelet()
	if (dx < 0 || dy < 0) {
		reverse();
		return;
	}

	for (cellidx x = 0; x < dx; ++x) {
		for (cellidx y = 0; y < dy; ++y) {
			space[tx+x, ty+y] = space[ox+x, oy+y];
			space[ox+x, oy+y] = cell.init;
		}
	}
}
void dixiecup() {
	cellidx ox, oy, dx, dy, tx, ty;

	popVector        (tx, ty);
	popVector!(false)(dx, dy);
	popVector        (ox, oy);

	if (!dx || !dy)
		return;

	// see comment in bracelet()
	if (dx < 0 || dy < 0) {
		reverse();
		return;
	}

	for (cellidx x = dx; x--;) {
		for (cellidx y = dx; y--;) {
			space[tx+x, ty+y] = space[ox+x, oy+y];
			space[ox+x, oy+y] = cell.init;
		}
	}
}

void chicane() {
	cellidx x, y, dx, dy;
	popVector        ( x,  y);
	popVector!(false)(dx, dy);

	cell c = ip.stack.pop;

	for (cellidx i = x; i < x + dx; ++i)
		for (cellidx j = y; j < y + dy; ++j)
			space[i, j] = c;
}

void fishhook() {
	auto n = cast(cellidx)ip.stack.pop;

	if (!n)
		return;
	else if (n < 0) {
		for (cellidx y = space.begY; y <= space.endY; ++y)
			space[ip.x, y+n] = space[ip.x, y];

		for (cellidx y = space.begY + n; y < space.begY; ++y) {
			if (space[ip.x, y] != ' ') {
				space.begY = y;
				break;
			}
		}
	} else if (n > 0) {
		for (cellidx y = space.endY; y >= space.begY; --y)
			space[ip.x, y+n] = space[ip.x, y];

		for (cellidx y = space.endY + n; y > space.endY; --y) {
			if (space[ip.x, y] != ' ') {
				space.endY = y;
				break;
			}
		}
	}
}

void boulder() {
	auto n = cast(cellidx)ip.stack.pop;

	if (!n)
		return;
	else if (n < 0) {
		for (cellidx x = space.begX; x <= space.endX; ++x)
			space[x+n, ip.y] = space[x, ip.y];

		for (cellidx x = space.begX + n; x < space.begX; ++x) {
			if (space.unsafeGet(x, ip.y) != ' ') {
				space.begX = x;
				break;
			}
		}
	} else if (n > 0) {
		for (cellidx x = space.endX; x >= space.begX; --x)
			space[x+n, ip.y] = space[x, ip.y];

		for (cellidx x = space.endX + n; x > space.endX; --x) {
			if (space.unsafeGet(x, ip.y) != ' ') {
				space.endX = x;
				break;
			}
		}
	}
}

void corner() {
	cellidx x  = ip.x,
	        y  = ip.y,
	        dx = ip.dx,
	        dy = ip.dy;

	turnLeft();
	ip.move();
	ip.stack.push(space[ip.x, ip.y]);

	ip.x = x;
	ip.y = y;
	ip.dx = dx;
	ip.dy = dy;
}

// can opener
void canOpener() {
	cellidx x  = ip.x,
	        y  = ip.y,
	        dx = ip.dx,
	        dy = ip.dy;

	turnRight();
	ip.move();
	ip.stack.push(space[ip.x, ip.y]);

	ip.x = x;
	ip.y = y;
	ip.dx = dx;
	ip.dy = dy;
}

// doric column
void doricColumn() { with (ip.stack) push(pop + cast(cell)1); }

// toilet seat
void toiletSeat()  { with (ip.stack) push(pop - cast(cell)1); }

// lightning bolt
void lightningBolt() { with (ip.stack) push(-pop); }

// pair of stilts
void pairOfStilts() {
	with (ip.stack) {
		cell b = pop,
		     a = pop;

		if (b < 0)
			push(a >> (-b));
		else
			push(a << b);
	}
}

void gable() {
	with (ip.stack) for (cell n = pop, c = pop; n--;)
		push(c);
}

// pair of shoes
void pairOfShoes() {
	with (ip.stack) {
		auto y = pop, x = pop;
		push(x+y, x-y);
	}
}

// pitchfork head
void pitchforkHead() {
	cell sum = 0;
	foreach (c; ip.stack)
		sum += c;
	ip.stack.clear();
	ip.stack.push(sum);
}

void mailbox() {
	cell prod = 1;
	foreach (c; ip.stack)
		prod *= c;
	ip.stack.clear();
	ip.stack.push(prod);
}

void calipers() {
	cellidx tx, ty, i, j;

	popVector(tx, ty);

	with (ip.stack) {
		// j's location not in spec...
		j = cast(cellidx)pop;
		i = cast(cellidx)pop;

		for (auto y = ty; y < ty + j; ++y)
			for (auto x = tx; x < tx + i; ++x)
				space[x, y] = pop;
	}
}
void counterclockwise() {
	cellidx ox, oy, i, j;

	popVector(ox, oy);

	with (ip.stack) {
		// j's location not in spec...
		j = cast(cellidx)pop;
		i = cast(cellidx)pop;

		for (auto y = oy + j; y-- > oy;)
			for (auto x = ox + i; x-- > ox;)
				push(space[x, y]);
	}
}

void necklace() {
	cell v = ip.stack.pop;
	cellidx x = ip.x,
	        y = ip.y;

	reverse();
	ip.move();
	space[ip.x, ip.y] = v;
	ip.x = x;
	ip.y = y;
	reverse();
}

void barstool() {
	switch (ip.stack.pop) {
		case 0: eastWestIf(); break;
		case 1: northSouthIf(); break;
		default: reverse(); break;
	}
}

void tumbler() {
	switch (rand_up_to!(4)()) {
		case 0: space[ip.x, ip.y] = '<'; goWest (); break;
		case 1: space[ip.x, ip.y] = '>'; goEast (); break;
		case 2: space[ip.x, ip.y] = 'v'; goSouth(); break;
		case 3: space[ip.x, ip.y] = '^'; goNorth(); break;
		default: assert (false);
	}
}

// television antenna
void televisionAntenna() {
	cellidx x, y;
	popVector(x, y);

	auto v = ip.stack.pop,
	     c = space[x, y];

	if (c < v) with (ip.stack) {
		push(v);
		pushVector(x, y);
		reverse();
		ip.move();
		reverse();
	} else if (c > v)
		reverse();
}

// buried treasure
void buriedTreasure() { ++ip.x; }
void slingshot()      { ++ip.y; }
