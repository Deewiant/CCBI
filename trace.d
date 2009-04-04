// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2006-06-14 11:52:53

// The tracing facilities.
module ccbi.trace;

import tango.io.Console : Cin;
import tango.io.Stdout;
import tango.text.convert.Integer : toInt, toLong;
import tango.text.Util            : trim, split;

import ccbi.container;
import ccbi.ip;
import ccbi.space;
import ccbi.stdlib;

// tip = traced IP OWTTE
IP* tip;

bool trace;

// ips might have moved after it's messed with
// hence pointers break
// ip is fine, it always gets reset
// but tip needs to be found again
void tipSafe(void delegate() messWithIps) {
	if (!tip)
		return messWithIps();

	// this might not work with TRDS as it allows for multiple IPs with the same ID
	// but too bad
	auto id   = tip.id;
	auto prev = ips.ptr;

	messWithIps();

	if (ips.ptr != prev)
		return tip = findIP(id);
}

bool doTrace() {
	const DEBUGHELP =
"(h)elp      --  Show this help text
e(x)plain   --  Explains the meaning of the mode string
i(n)fo      --  Repeat the short info shown after every step
(s)tep      --  Step one instruction
(r)un       --  Continue execution until any IP hits a breakpoint
(b)reak     --  Toggle the breakpoint for the current IP
(g)break    --  Toggle the global breakpoint
(c)break    --  Set the cell on which to break (won't break in stringmode)
de(l)ay     --  Set the tick until which to delay
s(t)ack     --  Show the stack(s) of the current IP
(a)rea      --  Show an area of Funge-Space in its current state
(v)iew      --  Show the value of a single cell in Funge-Space
(e)dit      --  Set the value of a cell in Funge-Space
(i)ps       --  Show information about each active IP
s(w)itch    --  Switch tracing to a different IP
(p)osition  --  Set the position of the current IP
(d)elta     --  Set the delta of the current IP
(o)ffset    --  Set the storage offset of the current IP
(k)ill      --  Kill the current IP
(q)uit      --  Quit the program"
	;

	const MODESTRING =
`The complete mode string is "HIQST.
If any of the five characters is a space, that mode is not set.

" stands for stringmode.
H stands for hovermode.
I stands for invertmode.
Q stands for queuemode.
S stands for switchmode.
T stands for being a time traveler from the future.

The middle four are modes related to the MODE fingerprint.
The last is related to the TRDS fingerprint.`
	;

	static bool running,
	            breakSet,
	            cellBreakSet;
	static cellidx breakX, breakY;
	static cell cellBreak;
	static typeof(ticks) tickBreak = 0;

	bool atBreak = false;
	size_t breaker = void;

	if (breakSet) foreach (idx, i; ips)
	if (i.x == breakX && i.y == breakY) {
		atBreak = true;

		if (ips.length > 1) {
			Stderr.formatln(
				"IP {}, with ID {}, hit the global breakpoint at ( {} {} ).",
				idx, i.id, breakX, breakY);
		}
	}
	if (cellBreakSet) foreach (idx, i; ips)
	if (!(i.mode & IP.STRING) && space[i.x, i.y] == cellBreak) {
		atBreak = true;

		if (ips.length > 1) {
			Stderr.format(
				"IP {}, with ID {}, hit a cell with value ",
				idx, i.id);
			printCell!("", "." ~ NewlineString, " ", true)(cellBreak);
		}
	}

	if (running && !atBreak
	            && !(tip && (tip.mode & IP.BREAK_SET) && tip.x == tip.breakX && tip.y == tip.breakY)
	            && ticks != tickBreak
	)
		return true;

	running = false;

	Stdout.stream.flush();

	static size_t index;
	size_t ipCount = ips.length;

	foreach (i; ips)
	if (ticks < i.jumpedTo)
		--ipCount;

	if (tip) {
		foreach (idx, i; ips)
		if (tip is &i) {
			index = idx;
			break;
		}
	} else {
		Stderr.formatln("Switched traced IP to IP 0 since the previous IP {} disappeared.", index);
		tip = &ips[0];
		index = 0;
		Stderr.formatln("New traced IP has ID {}.", tip.id);
	}

	void showInfo() {
		auto i = space[tip.x, tip.y];
		printCell!(NewlineString ~ "Instruction: ", " --- Stack: ")(i);
		Stderr.formatln("{} cell(s): {}", tip.stack.size, stackString(tip));
		Stderr.formatln("Position: ( {} {} ) --- Delta: ( {} {} ) --- Offset: ( {} {} )", tip.x, tip.y, tip.dx, tip.dy, tip.offsetX, tip.offsetY);
		Stderr.formatln("Tick: {} --- Index/IPs: {}/{} --- ID: {} --- Stacks: {} --- Mode: {}" ~ NewlineString, ticks, index, ipCount, tip.id, tip.stackStack.size, modeString(tip));
	}

	showInfo();

	bool done;
	do {
		Stderr("(debug prompt) ").stream.flush;

		static char[] last;

		char[] input;
		Cin.readln(input);
		if (input.length)
			last = input.dup;
		else
			input = last;

		switch (input) {
			case "h", "hlp", "?", "help": Stderr(DEBUGHELP ).newline; break;
			case "x", "explain":          Stderr(MODESTRING).newline; break;
			case "s", "step": return true;
			case "r", "run" : return (running = true);
			case "k", "kill": Stderr.formatln("Succesfully killed IP {}", tip.id); stateChange = State.STOPPING; return false;
			case "q", "quit": stateChange = State.QUITTING; return false;
			case "n", "info": showInfo(); break;
			case "b", "break":
				if (tip.mode & IP.BREAK_SET) {
					tip.mode &= ~IP.BREAK_SET;
					Stderr.formatln("Breakpoint of IP {} at ( {} {} ) turned off.", tip.id, tip.breakX, tip.breakY);
					break;
				}

				Stderr("Enter x and y coordinates for the breakpoint, separated by a space: ");
				tip.mode |= (read(&tip.breakX, &tip.breakY) ? IP.BREAK_SET : 0);
				if (tip.mode & IP.BREAK_SET)
					Stderr.formatln("Breakpoint of IP {} set to ( {} {} ).", tip.id, tip.breakX, tip.breakY);
				else
					Stderr("Breakpoint not set.").newline;
				break;

			case "g", "gbreak":
				if (breakSet) {
					breakSet = false;
					Stderr.formatln("Global breakpoint at ( {} {} ) turned off.", breakX, breakY);
					break;
				}

				Stderr("Enter x and y coordinates for the breakpoint, separated by a space: ");
				breakSet = read(&breakX, &breakY);
				if (breakSet)
					Stderr.formatln("Global breakpoint set to ( {} {} ).", breakX, breakY);
				else
					Stderr("Global breakpoint not set.").newline;
				break;

			case "c", "cbreak":
				if (cellBreakSet) {
					cellBreakSet = false;
					printCell!("No longer breaking on every cell with value ", ".\n", ", character ", true)(cellBreak);
					break;
				}

				Stderr("Enter cell value to break on: ");
				cellBreakSet = read(&cellBreak);
				if (cellBreakSet)
					printCell!("Breaking on every cell with value ", ".\n", ", character ", true)(cellBreak);
				else
					Stderr("Cell break not set.").newline;
				break;

			case "l", "delay":
				if (tickBreak) {
					tickBreak = 0;
					Stderr.formatln("No longer delaying until tick {}.", tickBreak);
					break;
				}

				Stderr("Enter tick to delay until: ");
				if (read(cast(long*)&tickBreak))
					Stderr.formatln("Delaying until tick {}.", tickBreak);
				else
					Stderr("Delay not set.").newline;
				break;

			case "t", "stack":
				Stderr.formatln("{} stack(s):", tip.stackStack.size);

				size_t i = 1;
				foreach (st; &tip.stackStack.topToBottom)
					Stderr.formatln(" Stack {,2:}, {,4:} element(s):", i++, st.size)("  ")(toUtf8(st.elementsBottomToTop)).newline;
				Stderr.newline;
				break;

			case "a", "area":
				Stderr("Enter x and y coordinates for the top left corner, separated by a space: ");
				cellidx tlX, tlY;
				if (!read(&tlX, &tlY)) {
					Stderr("Cancelled viewing of area of Funge-Space.").newline;
					break;
				}

				Stderr("Enter x and y coordinates for the size of the area to be viewed, similarly: ");
				cellidx szX, szY;
				if (!read(&szX, &szY)) {
					Stderr("Cancelled viewing of area of Funge-Space.").newline;
					break;
				}

				if (szX <= 0 || szY <= 0) {
					Stderr("Invalid input: cannot view rectangle with negative or zero side length.").newline;
					break;
				}

				// where "br" is of course "bottom right"
				cellidx
					brY = tlY + szY,
					brX = tlX + szX;

				// trim spaces before EOL
				auto line = new char[szX];

				for (cellidx y = tlY; y < brY; ++y) {
					for (cellidx x = tlX; x < brX; ++x)
						line[x - tlX] = space[x, y];

					Stderr(stripr(line)).newline;
				}
				break;

			case "v", "view":
				Stderr("Enter the x and y coordinates of the cell, separated by a space: ");
				cellidx x, y;
				if (!read(&x, &y)) {
					Stderr.formatln("Cancelled viewing of cell.");
					break;
				}

				auto c = space[x, y];

				Stderr.format("Cell ( {} {} ): value ", x, y);
				printCell!("", NewlineString, ", character ", true)(c);
				break;

			case "e", "edit":
				Stderr("Enter the x and y coordinates of the cell, separated by a space: ");
				cellidx x, y;
				if (!read(&x, &y)) {
					Stderr.formatln("Cancelled editing of cell.");
					break;
				}

				cell c;
				Stderr("Enter the value to set the cell to: ");
				if (!read(&c)) {
					Stderr.formatln("Cancelled editing of cell.");
					break;
				}

				space[x, y] = c;

				Stderr.format("Set cell ( {} {} ) to ", x, y);
				printCell!("", NewlineString, " ", true)(c);

				break;

			case "i", "ips":
				Stderr.formatln("{} IPs, in reverse order of execution:", ipCount);
				foreach (idx, i; ips) {
					if (ticks < i.jumpedTo)
						continue;

					char[] str = "[".dup;
					foreach (st; &i.stackStack.bottomToTop)
						str ~= Stderr.layout.convert("{} ", st.size);
					str[$-1] = ']';

					Stderr.format(
						" IP {,2:} -- Position: ( {,3:} {,3:} ) - Delta: ( {} {} ) - ID: {}" ~ NewlineString ~
						"            Offset: ( {,3:} {,3:} ) - Breakpoint: ( {} {} ) {}" ~ NewlineString ~
						"              Mode: {}       - Stack number/sizes: {}/{}" ~ NewlineString ~
						"       Instruction: ",
						idx, i.x, i.y, i.dx, i.dy, i.id,
						i.offsetX, i.offsetY, i.breakX, i.breakY, i.mode & IP.BREAK_SET ? "ON" : "OFF",
						modeString(&i), i.stackStack.size, str
					);
					printCell!("", NewlineString ~ NewlineString)(space[i.x, i.y]);
				}
				break;

			case "w", "switch":
				Stderr("Enter the index of the IP to switch to: ");
				cell idxc;
				if (!read(&idxc)) {
					Stderr.formatln("Cancelled IP switch.");
					break;
				}
				auto idx = cast(size_t)idxc;

				if (idx < ips.length) {
					tip = &ips[idx];
					index = idx;
					Stderr.formatln("Traced IP switched to IP {}.", idx);
				} else
					Stderr.formatln("IP {} not found.", idx);
				break;

			case "p", "position":
				Stderr("Enter x and y coordinates for the new position, separated by a space: ");
				cellidx x, y;
				if (!read(&x, &y)) {
					Stderr("Cancelled setting IP position.").newline;
					break;
				}

				tip.x = x;
				tip.y = y;
				Stderr.formatln("IP moved to ( {} {} ).", x, y);
				needMove = false;

				break;

			case "d", "delta":
				Stderr("Enter x and y coordinates for the new delta, separated by a space: ");
				cellidx x, y;
				if (!read(&x, &y)) {
					Stderr("Cancelled setting IP delta.").newline;
					break;
				}

				tip.dx = x;
				tip.dy = y;

				Stderr.formatln("IP delta set to ( {} {} ).", x, y);
				break;

			case "o", "offset":
				Stderr("Enter x and y coordinates for the new offset, separated by a space: ");
				cellidx x, y;
				if (!read(&x, &y)) {
					Stderr("Cancelled setting IP storage offset.").newline;
					break;
				}

				tip.offsetX = x;
				tip.offsetY = y;

				Stderr.formatln("IP storage offset set to ( {} {} ).", x, y);
				break;

			default:
				Stderr.formatln("Undefined command '{}'. See 'help'.", input);
				break;
		}
	} while (!done);

	return true;
}

private:

void printCell(char[] pre = "", char[] post = "", char[] mid = " ", bool bracket = false)(cell c) {
	static if (bracket)
		Stderr.format("{}{1} (0x{1:x}){}'{}'{}", pre, c, mid, cast(char)c, post);
	else
		Stderr.format("{}{1} 0x{1:x}{}'{}'{}",   pre, c, mid, cast(char)c, post);
}

bool read(cell*[] cs...) { return read(cast(cellidx*[])cs); }
bool read(cellidx*[] cs...) {
	Stderr.stream.flush;

	char[] line;
	Cin.readln(line);
	auto apart = split(trim(line), " ");

	if (apart.length < cs.length) {
		Stderr("Too few parameters in input.").newline;
		return false;
	}

	// the toInt below will have to be changed if this fails
	// cheers to Walter Bright at
	// http://d.puremagic.com/issues/show_bug.cgi?id=196
	static if (is (cellidx base == typedef))
		static assert (
			is (base == int),
			"cellidx is not int: "
			"change conversion function used in ccbi.trace.read()");
	else
		static assert (false, "cellidx is not a typedef: something's wrong");

	foreach (i, c; cs) {
		try *c = cast(cellidx)toInt(apart[i]);
		catch {
			Stderr.formatln("'{}' is invalid.", apart[i]);
			return false;
		}
	}

	return true;
}
bool read(long* ul) {
	Stderr.stream.flush;

	char[] line;
	Cin.readln(line);

	try *ul = toLong(line);
	catch {
		Stderr.formatln("'{}' is invalid.", line);
		return false;
	}

	return true;
}

char[] stackString(in IP* ip) {
	char[] stackStr = "[".dup;

	cell[8] onesToShow;
	auto numShown =
		ip.stack.size > onesToShow.length
			? onesToShow.length
			: ip.stack.size;

	foreach_reverse (inout c; onesToShow)
		c = ip.stack.popHead;

	ip.stack.pushHead(onesToShow[$-numShown..$]);

	assert (ip.stack.size >= numShown);

	foreach (c; onesToShow[$-numShown..$])
		stackStr ~= Stderr.layout.convert("{} ", c);

	for (size_t j = 0; j < onesToShow.length - numShown; ++j)
		stackStr ~= "- ";

	stackStr[$-1] = ']';

	return stackStr;
}

char[] modeString(in IP* ip) {
	char[] str = "      ".dup;
	size_t i = 0;

	if (ip.mode & IP.STRING) str[i++] = '"';
	if (ip.mode & IP.HOVER)  str[i++] = 'H';

	auto q = cast(Deque)ip.stack;
	if (q) {
		if (q.mode & QUEUE_MODE)  str[i++] = 'Q';
		if (q.mode & INVERT_MODE) str[i++] = 'I';
	}

	if (ip.mode & IP.SWITCH)      str[i++] = 'S';
	if (ip.mode & IP.FROM_FUTURE) str[i++] = 'T';

	return str;
}

char[] toUtf8(cell[] cells) {
	if (!cells.length)
		return "[]";
	char[] str = "[".dup;
	foreach (cell; cells)
		str ~= Stderr.layout.convert("{} ", cell);
	str[$-1] = ']';
	return str;
}
