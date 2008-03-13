// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:10:55

module ccbi.fingerprints.cats_eye.mode; private:

import ccbi.container;
import ccbi.fingerprint;
import ccbi.instructions;
import ccbi.ip;
import ccbi.space;

// 0x4d4f4445: MODE
// Funge-98 Standard Modes
// -----------------------

static this() {
	mixin (Code!("MODE"));

	fingerprints[MODE]['H'] =& toggleHovermode;
	fingerprints[MODE]['I'] =& toggleInvertmode;
	fingerprints[MODE]['Q'] =& toggleQueuemode;
	fingerprints[MODE]['S'] =& toggleSwitchmode;

	fingerprintConstructors[MODE] =& ctor;
	fingerprintDestructors [MODE] =& dtor;
}

void ctor() {
	foreach (inout i; ips) {
		foreach (inout s; i.stackStack)
			s = new Deque(s);
		i.stack = i.stackStack.top;
	}

	instructions['>'] =& hoverGoEast;
	instructions['<'] =& hoverGoWest;
	instructions['^'] =& hoverGoNorth;
	instructions['v'] =& hoverGoSouth;
	instructions['|'] =& hoverNorthSouthIf;
	instructions['_'] =& hoverEastWestIf;

	instructions['['] =& switchTurnLeft;
	instructions[']'] =& switchTurnRight;
	instructions['{'] =& switchBeginBlock;
	instructions['}'] =& switchEndBlock;
	instructions['('] =& switchLoadSemantics;
	instructions[')'] =& switchUnloadSemantics;
}

void dtor() {
	// leaving modes on after unloading is bad practice IMHO, but it could happen...
	foreach (i; ips)
	if ((i.mode & (IP.HOVER | IP.SWITCH)) || (i.stack.mode & (INVERT_MODE | QUEUE_MODE)))
		return;

	foreach (inout i; ips) {
		foreach (inout s; i.stackStack)
			s = new Stack!(cell)(s);
		i.stack = i.stackStack.top;
	}

	instructions['>'] =& goEast;
	instructions['<'] =& goWest;
	instructions['^'] =& goNorth;
	instructions['v'] =& goSouth;
	instructions['|'] =& northSouthIf;
	instructions['_'] =& eastWestIf;

	instructions['[']  =& turnLeft;
	instructions[']']  =& turnRight;
	instructions['{']  =& beginBlock;
	instructions['}']  =& endBlock;
	instructions['(']  =& loadSemantics;
	instructions[')']  =& unloadSemantics;
}

void hoverGoEast () { if (ip.mode & IP.HOVER) ++ip.dx; else goEast (); }
void hoverGoWest () { if (ip.mode & IP.HOVER) --ip.dx; else goWest (); }
void hoverGoNorth() { if (ip.mode & IP.HOVER) --ip.dy; else goNorth(); }
void hoverGoSouth() { if (ip.mode & IP.HOVER) ++ip.dy; else goSouth(); }

void hoverEastWestIf()   { if (ip.mode & IP.HOVER) { if (ip.stack.pop) hoverGoWest();  else hoverGoEast();  } else eastWestIf  (); }
void hoverNorthSouthIf() { if (ip.mode & IP.HOVER) { if (ip.stack.pop) hoverGoNorth(); else hoverGoSouth(); } else northSouthIf(); }

void switchTurnLeft()        { if (ip.mode & IP.SWITCH) space[ip.x, ip.y] = ']'; turnLeft();        }
void switchTurnRight()       { if (ip.mode & IP.SWITCH) space[ip.x, ip.y] = '['; turnRight();       }
void switchBeginBlock()      { if (ip.mode & IP.SWITCH) space[ip.x, ip.y] = '}'; beginBlock();      }
void switchEndBlock()        { if (ip.mode & IP.SWITCH) space[ip.x, ip.y] = '{'; endBlock();        }
void switchLoadSemantics()   { if (ip.mode & IP.SWITCH) space[ip.x, ip.y] = ')'; loadSemantics();   }
void switchUnloadSemantics() { if (ip.mode & IP.SWITCH) space[ip.x, ip.y] = '('; unloadSemantics(); }

// Toggle Hovermode, Toggle Switchmode, Toggle Invertmode, Toggle Queuemode
void toggleHovermode () { ip.mode ^= IP.HOVER;  }
void toggleSwitchmode() { ip.mode ^= IP.SWITCH; }
void toggleInvertmode() { auto q = cast(Deque)(ip.stack); assert (q !is null); q.mode ^= INVERT_MODE; }
void toggleQueuemode () { auto q = cast(Deque)(ip.stack); assert (q !is null); q.mode ^= QUEUE_MODE;  }
