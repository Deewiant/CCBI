// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-06-16 14:26:51

module ccbi.mini.instructions;

import tango.io.Stdout : Stderr;

import ccbi.instructions;
import ccbi.ip;
import ccbi.utils : popVector;

import ccbi.mini.vars;

void miniExecuteInstruction(cell i) {
switch (i) {
	case '@' : miniStop;            break; 
	case ' ' : miniAscii32;         break; 
	case ';' : miniJumpOver;        break; 
	case '\'': miniFetchCharacter;  break; 
	case 's' : miniStoreCharacter;  break; 
	case 'k' : miniIterate;         break; 
	case 'B' : miniB;               break; 
	case 'D' : miniD;               break; 
	case 'E' : miniE;               break; 
	case 'F' : miniF;               break; 
	case 'G' : miniG;               break; 
	case 'K' : miniK;               break; 
	case 'L' : miniL;               break; 
	case 'O' : miniO;               break; 
	case 'P' : miniP;               break; 
	case 'R' : miniR;               break; 
	default: executeInstruction(i); break;
}}

void miniUnimplemented() {
	auto i = miniIp.space.unsafeGet(miniIp.x, miniIp.y);
	Stderr.formatln(
		"Unavailable instruction '{0}'({1:d}) (0x{1:x}) encountered at ({}, {}) in Mini-Funge.",
		cast(char)i, i, miniIp.x, miniIp.y
	);
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

	if (i == '$')
		return ip.stack.pop(n);

	ip.x = x;
	ip.y = y;
	scope (success)
	if (ip.x == x && ip.y == y && ip.dx == dx && ip.dy == dy)
		ip.move();

	if (n >= 10) switch (i) {
		case 'v', '^', '<', '>', 'n', '?', '@', 'q':
			return executeInstruction(i);
		case 'r':
			if (i & 1)
				reverse();
			return;
		default:
			break;
	}

	while (n--)
		executeInstruction(i);
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
