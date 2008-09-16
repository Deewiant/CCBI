// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2006-06-12 11:24:55

// The Instruction Pointer.
module ccbi.ip;

import tango.stdc.string : memcpy;
import tango.time.Time;

public import ccbi.cell;
       import ccbi.container;
       import ccbi.fingerprint;
       import ccbi.space;

IP*  ip; // the current ip
IP[] ips;

enum State : byte {
	UNCHANGING = 0,
	STOPPING,
	QUITTING,
	TIMEJUMP // for TRDS
}
State stateChange;

IP* findIP(cell id) {
	for (size_t i = 0; i < ips.length; ++i)
		if (ips[i].id == id)
			return &ips[i];
	return null;
}

bool needMove = true;
ulong ticks = 0;

// for TRDS
struct StoppedIPData {
	cell id;
	int jumpedAt, jumpedTo;
}
StoppedIPData[] stoppedIPdata;
IP[] travelers;

struct IP {
	static IP opCall() {
		IP ip;
		with (ip) {
			id = parentID = 0;

			stackStack = new typeof(stackStack)(1u);
			stack      = new Stack!(cell);
			stackStack.push(stack);

			foreach (j, inout i; mapping)
				i = cast(cell)j;

			for (cell i = 'A'; i <= 'Z'; ++i)
				semantics[i] = new typeof(semantics[i])('Z' - 'A' + 1u);

			space = &.space;
		}
		return ip;
	}

	// only used for Mini-Funge IPs
	static IP opCall(typeof(.space)* s, typeof(ip) i) {
		IP ip;
		with (ip) {
			id = i.id;
			stack = i.stack;
			space = s;
		}
		return ip;
	}

	IP copy() {
		IP i;
		memcpy(&i, this, i.sizeof);

		i.stackStack = new typeof(stackStack)(this.stackStack);

		/+ new each stack with itself as an argument
		 + so that they are copies,
		 + not pointing to the same data
		 +/
		bool deque = cast(Deque)this.stack !is null;

		foreach (inout stack; i.stackStack) {
			alias Container!(cell) CC;
			alias Stack    !(cell) Ctack;

			stack = (deque
				? cast(CC)new Deque(cast(Deque)stack)
				: cast(CC)new Ctack(cast(Ctack)stack)
			);
		}

		i.stack = i.stackStack.top;

		i.semantics = null; // allocate a new semantics for the child
		foreach (key, st; semantics) {
			i.semantics[key] = new Stack!(Semantics);
			i.semantics[key].push(st.elementsBottomToTop);
		}

		return i;
	}

	void move() {
		auto nx = x + dx;
		auto ny = y + dy;

		if (!space.inBounds(nx, ny)) {
			do {
				nx -= dx;
				ny -= dy;
			} while (space.inBounds(nx, ny));
			nx += dx;
			ny += dy;
		}

		x = nx;
		y = ny;
	}

	// eat spaces and semicolons, the zero-tick instructions
	void gotoNextInstruction() {
		if (mode & STRING) {
			if ((*space)[x, y] == ' ') {
				// SGML spaces: move past all but one space
				cellidx nx = void, ny = void;
				do {
					nx = x;
					ny = y;
					move();
				} while ((*space)[x, y] == ' ');

				x = nx;
				y = ny;
			}
		} else for (;;) {
			if ((*space)[x, y] == ' ') {
				// no operation until next non-' ', takes no time
				do move();
				while ((*space)[x, y] == ' ');
			}

			if ((*space).unsafeGet(x, y) == ';') {
				// no operation until next ';', takes no time
				do move();
				while ((*space)[x, y] != ';');
				move();
			} else break;
		}
	}

	Container!(cell) newStack() {
		return (cast(Deque)stack
			? cast(Container!(cell))new Deque
			: cast(Container!(cell))new Stack!(cell)
		);
	}

	typeof(.space)* space = null;

	cellidx
		x       = 0,
		y       = 0,
		dx      = 1,
		dy      = 0,
		offsetX = 0, // storage offset
		offsetY = 0,
		breakX, // breakpoint; for debugging, used only when tracing
		breakY;

	// parentID for IIPC
	cell id = void, parentID = void;

	// timeStopper for TRDS
	static cell
		currentID   = CURRENTID_INIT,
		timeStopper = TIMESTOPPER_INIT;

	// thanks to the new .init behaviour in 2.001 / 1.017...
	static const cell
		CURRENTID_INIT   = 0,
		TIMESTOPPER_INIT = cell.max;

	Container!(cell) stack;
	Stack!(typeof(stack)) stackStack;
	Stack!(Semantics)[char] semantics;

	cell[256] mapping = void; // for IMAP

	enum : typeof(mode) {
		STRING        = 1 <<  0,
		BREAK_SET     = 1 <<  1,
		HOVER         = 1 <<  2, // these two for MODE
		SWITCH        = 1 <<  3,
		DORMANT       = 1 <<  4, // for IIPC
		ABS_SPACE     = 1 <<  5, // next five for TRDS
		SPACE_SET     = 1 <<  6,
		ABS_TIME      = 1 <<  7,
		TIME_SET      = 1 <<  8,
		DELTA_SET     = 1 <<  9,
		FROM_FUTURE   = 1 << 10, // for tracing TRDS
		SUBR_RELATIVE = 1 << 11  // for SUBR
	}

	ushort mode = 0;

	// for HRTI
	auto timeMark = Time.min;

	// the rest for TRDS

	typeof( x) tardisX,  tardisReturnX;
	typeof( y) tardisY,  tardisReturnY;
	typeof(dx) tardisDx, tardisReturnDx;
	typeof(dy) tardisDy, tardisReturnDy;

	// int because the TRDS specs don't take into account more than 32 bits
	int tardisTick, tardisReturnTick, jumpedTo, jumpedAt;
}
