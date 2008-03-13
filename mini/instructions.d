// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-06-16 14:26:51

module ccbi.mini.instructions;

import ccbi.ip;
import ccbi.utils : popVector;

import ccbi.mini.vars;

void function()[128] miniIns;

static this() {
	miniIns['@']  =& miniStop;
	miniIns[' ']  =& miniAscii32;
	miniIns[';']  =& miniJumpOver;
	miniIns['\''] =& miniFetchCharacter;
	miniIns['s']  =& miniStoreCharacter;
	miniIns['k']  =& miniIterate;
	miniIns['B']  =& miniB;
	miniIns['D']  =& miniD;
	miniIns['E']  =& miniE;
	miniIns['F']  =& miniF;
	miniIns['G']  =& miniG;
	miniIns['K']  =& miniK;
	miniIns['L']  =& miniL;
	miniIns['O']  =& miniO;
	miniIns['P']  =& miniP;
	miniIns['R']  =& miniR;
}

void miniStop() { mOver = true; }
void miniAscii32() {
	do ip.move();
	while ((*mSpace)[ip.x, ip.y] == ' ');

	mNeedMove = false;
}
void miniJumpOver() {
	do ip.move();
	while ((*mSpace)[ip.x, ip.y] != ';');
}
void miniFetchCharacter() {
	ip.move();
	ip.stack.push((*mSpace)[ip.x, ip.y]);
}
void miniStoreCharacter() {
	ip.move();
	(*mSpace)[ip.x, ip.y] = ip.stack.pop;
}
void miniIterate() {
	auto
		n  = ip.stack.pop,
		x  = ip.x,
		y  = ip.y,
		dx = ip.dx,
		dy = ip.dy;

	ip.move();

	if (n <= 0)
		return;

	auto i = (*mSpace)[ip.x, ip.y];

	if (i == ' ' || i == ';' || i == 'z')
		return;

	if (i == '$') {
		ip.stack.pop(n);
		return;
	}

	ip.x = x;
	ip.y = y;
	scope (success)
	if (ip.x == x && ip.y == y && ip.dx == dx && ip.dy == dy)
		ip.move();

	auto ins = miniIns[i];

	if (n >= 10)
	switch (i) {
		case 'v', '^', '<', '>', 'n', '?', '@', 'q': return ins();
		case 'r':
			if (i & 1)
				miniIns['r']();
			return;
		default:
			if (ins is null)
				goto case 'r';
			break;
	}

	while (n--)
		ins();
}

void miniB() {
	miniR();
	rip.move();
	miniR();
}
void miniF() { rip.move(); }

void miniD() {
	cellidx x, y;
	popVector(x, y);
	rip.dx = x;
	rip.dy = y;
}
void miniL() {
	cellidx x, y;
	popVector(x, y);
	rip.x = x;
	rip.y = y;
}

void miniE() { ip.stack.push(cast(cell)ip.stack.size); }

void miniG() {
	cellidx x, y;
	popVector!(true)(x, y);
	ip.stack.push((*mSpace)[x, y]);
}
void miniP() {
	cellidx x, y;
	popVector!(true)(x, y);

	auto c = ip.stack.pop;

	if (y > mSpace.endY)
		mSpace.endY = y;
	else if (y < mSpace.begY)
		mSpace.begY = y;
	if (x > mSpace.endX)
		mSpace.endX = x;
	else if (x < mSpace.begX)
		mSpace.begX = x;

	(*mSpace)[x, y] = c;
}

void miniK() {
	with (ip.stack) {
		auto u = pop,
		     s = size;

		if (u >= s)
			push(0);
		else
			push(elementsBottomToTop[s - (u+1)]);
	}
}

void miniO() {
	with (ip.stack) {
		auto u = pop,
		     s = size;

		if (u >= s)
			push(0);
		else {
			auto elems = elementsBottomToTop;
			auto xu = elems[s - (u+1)];

			clear();

			push(elems[1..$]);
			push(xu);
		}
	}
}

void miniR() {
	rip.dx *= -1;
	rip.dy *= -1;
}
