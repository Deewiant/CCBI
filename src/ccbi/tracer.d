// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2006-06-14 11:52:53

// The tracing facilities.
module ccbi.tracer;

template Tracer() {

import tango.core.Array           : find;
import tango.core.Traits          : isSignedIntegerType, isUnsignedIntegerType;
import tango.io.Console           : Cin;
import tango.math.Math            : min;
import tango.text.convert.Integer : parse, convert;
import tango.text.Ascii           : icompare, toLower;

import ccbi.container;
import ccbi.stdlib;
import ccbi.space.space;

alias .Coords!(dim) Coords;

bool stopNext = true;

byte[IP][Coords            ]  bps; //      breakpoints
bool[IP][cell              ] cbps; // cell breakpoints
byte    [typeof(state.tick)] tbps; // tick breakpoints

void ipStopped(IP ip) {
	if (ip is tip)
		tip = null;

	foreach (pos; bps.keys)
	if (ip in bps[pos]) {
		bps[pos].remove(ip);

		if (bps[pos].length == 0)
			bps.remove(pos);
	}

	foreach (val; cbps.keys)
	if (ip in cbps[val]) {
		cbps[val].remove(ip);

		if (cbps[val].length == 0)
			cbps.remove(val);
	}
}

version (TRDS) {
	void ipJumpedToFuture(IP ip) {
		if (ip is tip)
			tip = null;
	}
	void jumpedToPast() { tip = null; }
}

bool doTrace() {
	const DEBUGHELP =
"A parameter enclosed in () is necessary, [] denotes optionality.
Where an IP parameter is optional, the default is the traced IP unless
otherwise specified.

Vectors, including positions and sizes, are specified with their coordinates
separated by spaces, e.g. '0 0' for the origin.

Stacks are printed with the topmost element to the right.

(h)elp
   Show this help text
e(x)plain
   Explains the meaning of the mode string

i(n)fo" ~(befunge93?"":" [ip]")~ "
   Show the short info displayed after every step"
~(befunge93?"":"
(i)ps
   Show information about each active IP
s(w)itch (ip)
   Switch tracing to a different IP")~ "

(s)tep
   Step one instruction
(r)un
   Continue execution until any IP hits a breakpoint
stdin [<] text
   Set the standard input stream of the program to read from the given text. If
   the \"<\" was given, treat it as a file name instead, redirecting the stream
   to read from that file.

(b)reak (pos)" ~(befunge93?"":" [ip]")~ "
   Toggle a breakpoint" ~(befunge93?"":", applies to all IPs by default")~ "
(c)break (value) [strmode boolean]" ~(befunge93?"":" [ip]")~ "
   Toggle a cell breakpoint, doesn't apply in stringmode by default" ~(befunge93?"":", applies to
   all IPs by default")~ "
de(l)ay (tick)
   Toggle a tick breakpoint
bs, bps" ~(befunge93?"":" [ip]")~ "
   Show a list of all breakpoints" ~(befunge93?"":" affecting IP, or all if not given")~ "

s(t)ack" ~(befunge93?"":" [ip]")~ "
   Show the stack" ~(befunge93?"":"(s) of an IP")~ "
(a)rea (pos) (size)
   Show an area of Funge-Space
(v)iew (pos)
   Show the value of a cell in Funge-Space
(e)dit (pos) (val)
   Set  the value of a cell in Funge-Space

(p)osition (pos)" ~(befunge93?"":" [ip]")~ "
   Set the position of the " ~(befunge93?"":"current ")~ "IP
(d)elta (vec)" ~(befunge93?"":" [ip]")~ "
   Set the delta of the " ~(befunge93?"":"current ")~ "IP"
~(befunge93?"":"
(o)ffset (pos) [ip]
   Set the storage offset of the current IP")~
"
"~(befunge93?"":"
(k)ill [ip]
   Kill an IP")~"
(q)uit
   Quit the program"
	;

	const MODESTRING =
befunge93 ?
`The only mode is ", which signifies stringmode.`
:
`The complete mode string is "HIQSDT.
If any of the five characters is a space, that mode is not set.

" stands for stringmode.
H stands for hovermode.                             (MODE fingerprint.)
I stands for invertmode.                            (MODE fingerprint.)
Q stands for queuemode.                             (MODE fingerprint.)
S stands for switchmode.                            (MODE fingerprint.)
D stands for being dormant.                         (IIPC fingerprint.)
T stands for being a time traveler from the future. (TRDS fingerprint.)`
	;

	void printIP(size_t i, IP ip) {
		Serr("Tracer :: ");
		static if (!befunge93)
			if (state.ips.length > 1)
				return Serr.format("IP {}, with ID {}, ", i, ip.id);

		Serr("The IP ");
	}

	Sout.flush();

	bool atBreak = false;
	size_t breaker = void;

	static if (befunge93)
		auto ips = [cip];
	else
		auto ips = state.ips;

	// Positions after skipping markers
	auto ipPositions = new Coords[ips.length];
	foreach (i, ip; ips) {
		auto p = ip.pos;
		ip.gotoNextInstruction();
		ipPositions[i] = ip.pos;
		ip.pos = p;
	}

	foreach (pos, ipSet; bps)
	foreach (i, ip; ips)
	if (
		(null in ipSet || ip in ipSet) &&
		(ip.pos == pos || ipPositions[i] == pos)
	) {
		atBreak = true;

		printIP(i, ip);
		Serr.formatln("hit the breakpoint at {}.", pos);
	}

	foreach (val, ipSet; cbps)
	foreach (i, ip; ips) {
		bool stringsAlso = false;
		     if (auto p = null in ipSet) stringsAlso = stringsAlso || *p;
		else if (auto p =   ip in ipSet) stringsAlso = stringsAlso || *p;
		else continue;

		if (
			(stringsAlso || !(ip.mode & ip.STRING)) &&
			(state.space[ip.pos] == val || state.space[ipPositions[i]] == val)
		) {
			atBreak = true;

			printIP(i, ip);
			printCell(val, "hit the cell breakpoint for ", "." ~ NewlineString);
		}
	}

	foreach (bp, ignored; tbps)
	if (state.tick == bp) {
		atBreak = true;

		Serr.formatln("Tracer :: hit the tick breakpoint at {}.", bp);
	}

	if (!atBreak && !stopNext)
		return true;

	stopNext = true;

	size_t index;
	auto ipCount = ips.length;

	bool[size_t] invalidIndices;
	auto minimalValid = size_t.max;

	foreach (i, ip; ips) {
		static if (GOT_TRDS) if (state.tick < ip.jumpedTo) {
			--ipCount;
			invalidIndices[i] = true;
			continue;
		}

		if (i < minimalValid)
			minimalValid = i;
	}

	if (tip) {
		foreach (i, ip; ips)
		if (tip is ip) {
			index = i;
			break;
		}
	} else static if (!befunge93) {
		Serr.formatln(
			"Switched traced IP to IP {} since the previous IP {} disappeared.",
			minimalValid, index);

		tip = ips[index = minimalValid];
		Serr.formatln("New traced IP has ID {}.", tip.id);
	}

	void showInfo(IP ip, size_t index) {
		printCell(
			state.space[ipPositions[index]], NewlineString ~ "Instruction: ");

		if (ip.pos != ipPositions[index]) {
			static if (befunge93)
				Serr(" (wrapped around at ");
			else
				printCell(state.space[ip.pos], " (via marker: ", " at ");
			Serr(ip.pos)(')');
		}

		Serr.newline.format(
			"Position: {} -- Delta: {}", ipPositions[index], ip.delta);

		static if (!befunge93)
			Serr.format(" -- Offset: {}", ip.offset);

		Serr.newline.formatln(
			"Stack: {} cell(s): {}", ip.stack.size, stackString(ip));

		static if (befunge93)
			Serr.formatln(
				"Tick: {} -- Mode: {}"~NewlineString, state.tick, modeString(ip));
		else
			Serr.formatln(
				"Tick: {} -- IPs: {} -- Index/ID: {}/{} -- Stacks: {} -- Mode: {}"
				~ NewlineString,
				state.tick, ipCount, index, ip.id,
				ip.stackCount, modeString(ip));
	}

	showInfo(tip, index);

	for (;;) {
		Serr("(Tracer) ").flush;

		static char[] last;

		char[] input;
		Cin.readln(input);
		if (input.length)
			last = input.dup;
		else
			input = last;

		auto args = words(input);
		toLower(args[0]);

		switch (args[0]) {
			case "h", "hlp", "?", "help": Serr(DEBUGHELP ).newline; break;
			case "x", "explain":          Serr(MODESTRING).newline; break;
			case "r", "run":
				stopNext = false;
				if (!bps.length && !cbps.length && !tbps.length)
					flags.tracing = false;
			case "s", "step":
				return true;

		static if (!befunge93) {
			// k [ip]
			case "k", "kill":
				auto idx = index;
				if (!readIpIndex(idx, args.arg(1), invalidIndices))
					break;

				Serr.formatln("Successfully killed IP {}.", idx);
				return stop(idx);
		}

			case "q", "quit", ":q": return false;

			// n [ip]
			case "n", "info": {
				auto ip = tip;
				if (readIP(ip, index, args.arg(1), invalidIndices))
					showInfo(ip, index);
				break;
			}

			case "stdin": {
				if (
					args.length-1 == 0
					|| (args.arg(1) == "<" && args.length-1 == 1)
				) {
					Serr("No text given.").newline;
					break;
				}
				if (args.arg(1) == "<") try {
					auto name = args[2];
					Sin = new typeof(Sin)(new File(name));
					Serr("Successfully set stdin to file '")(name)("'.").newline;
				} catch {
					Serr("Couldn't open file '")(args[2])("' for reading.").newline;
				} else {
					auto str = args[1];
					Sin = new typeof(Sin)(new Array(str));
					Serr("Successfully set stdin to string '")(str)("'.").newline;
				}
				break;
			}

			// bs [ip]
			case "bs", "bps": {
				if (!bps.length && !cbps.length && !tbps.length) {
					Serr("No breakpoints.").newline;
					break;
				}

				IP ip = null;
				size_t idx;

				static if (!befunge93)
					if (readIpIndex(idx, args.arg(1), invalidIndices))
						ip = ips[idx];

				Serr("Breakpoints");
				if (ip)
					Serr(" affecting IP ")(idx);
				Serr(':').newline;

				foreach (pos, ipSet; bps)
				if (!ip || ip in ipSet) {

					Serr("Position ")(pos)(", IPs:");
					foreach (i, ignored; ipSet) {
						Serr(' ');
						if (i is null)
							Serr("(all)");
						else static if (!befunge93)
							Serr(ips.find(i));
					}
					Serr.newline;
				}
				foreach (val, ipSet; cbps)
				if (!ip || ip in ipSet) {

					Serr("Cell ")(val)(", IPs:");
					foreach (i, stringsAlso; ipSet) {
						Serr(' ');
						if (i is null)
							Serr("(all)");
						else static if (!befunge93)
							Serr(ips.find(i));
						Serr(stringsAlso ? ",1" : ",0");
					}
					Serr.newline;
				}
				foreach (time, ignored; tbps)
					Serr("Tick ")(time).newline;

				break;
			}

		static if (!befunge93) {
			case "i", "ips": {
				Serr.formatln("{} IPs, in reverse order of execution:", ipCount);
				foreach (i, ip; ips) {
					static if (GOT_TRDS)
						if (state.tick < ip.jumpedTo)
							continue;

					char[] str = "[".dup;
					if (ip.stackStack)
						foreach (st; &ip.stackStack.bottomToTop)
							str ~= Serr.layout.convert("{} ", st.size);
					else
						str ~= Serr.layout.convert("{} ", ip.stack.size);
					str[$-1] = ']';

					Serr.format(" IP {,2:} -- Position: {}", i, ipPositions[i]);

					if (ip.pos != ipPositions[i]) {
						printCell(state.space[ip.pos], " (via marker: ", " at ");
						Serr(ip.pos)(')');
					}

					Serr.format(
						NewlineString ~
						"          Delta: {} - Offset: {}"
						~ NewlineString ~
						"          ID: {} - Mode: {}"
						~ NewlineString ~
						"          Stack number/sizes: {}/{}"
						~ NewlineString ~
						"          Instruction: ",
						ip.delta, ip.offset,
						ip.id, modeString(ip),
						ip.stackCount, str
					);
					printCell(
						state.space[ipPositions[i]], "", NewlineString~NewlineString, " ");
				}
				break;
			}
		}

			// b (pos) [ip]
			case "b", "bp", "break": {
				if (args.length-1 < dim) {
					Serr("No position given.").newline;
					break;
				}

				Coords pos;
				if (!readCoords(pos, args[1..1+dim]))
					break;

				size_t idx;
				IP ip = null;

				static if (!befunge93)
					if (readIpIndex(idx, args.arg(dim+1), invalidIndices))
						ip = ips[idx];

				if (pos in bps && ip in bps[pos]) {

					bps[pos].remove(ip);
					if (bps[pos].length == 0)
						bps.remove(pos);

					Serr("Tracer :: removed prior ");
				} else {
					bps[pos][ip] = 0;

					Serr("Tracer :: set a ");
				}
				if (ip)
					Serr.format("breakpoint for IP {}", idx);
				else
					Serr("global breakpoint");
				Serr.formatln(" at {}.", pos);
				break;
			}

			// c (val) [strings] [ip]
			case "c", "cbp", "cbreak": {
				if (args.length < 2) {
					Serr("No value given.").newline;
					break;
				}

				cell val;
				if (!readCell(val, args[1]))
					break;

				bool strings = false;
				readBool(strings, args.arg(2));

				size_t idx;
				IP ip = null;

				static if (!befunge93)
					if (readIpIndex(idx, args.arg(3), invalidIndices))
						ip = ips[idx];

				if (val in cbps && ip in cbps[val]) {

					cbps[val].remove(ip);
					if (cbps[val].length == 0)
						cbps.remove(val);

					Serr("Tracer :: removed prior ");
				} else {
					cbps[val][ip] = strings;

					Serr("Tracer :: set a ");
				}
				if (strings)
					Serr("stringmode-inclusive ");

				if (ip)
					Serr.format("cell breakpoint for IP {}", idx);
				else
					Serr("global cell breakpoint");

				printCell(val, " for cell value ", "." ~ NewlineString);
				break;
			}

			// l (tick)
			case "l", "tbp", "delay": {
				if (args.length < 2) {
					Serr("No tick given.").newline;
					break;
				}

				typeof(state.tick) tb;
				if (!read(tb, args[1]))
					break;

				if (tb in tbps) {
					tbps.remove(tb);
					Serr.formatln(
						"Tracer :: removed prior tick breakpoint {}.", tb);
				} else {
					tbps[tb] = 0;
					Serr.formatln(
						"Tracer :: set a tick breakpoint for tick {}.", tb);
				}
				break;
			}

			// t [ip]
			case "t", "stack": {
				auto ip = tip;
				if (!readIP(ip, index, args.arg(1), invalidIndices))
					break;

				void printStack(typeof(ip.stack) st, size_t i) {
					Serr(" Stack ");
					static if (befunge93)
						Serr("has");
					else
						Serr.format("{,2:},", i);

					auto n = st.size;
					Serr.format("{,4:} element(s):", n)(" [");

					auto j = n-1;
					foreach (c; &st.bottomToTop) {
						Serr(c);
						if (j-- > 0)
							Serr(' ');
					}
					Serr(']').newline.print(`                            "`);
					foreach (c; &st.bottomToTop)
						Serr(displayCell(c));
					Serr('"').newline;
				}

				static if (befunge93)
					printStack(ip.stack, 0);
				else {
					Serr(ip.stackCount)(" stack(s):").newline;

					if (ip.stackStack) {
						size_t i = 1;
						foreach (st; &ip.stackStack.topToBottom)
							printStack(st, i++);
					} else
						printStack(ip.stack, 1);
				}
				Serr.newline;
				break;
			}

			// a (pos) (size)
			case "a", "area": {
				if (args.length-1 < dim) {
					Serr("No position given.").newline;
					break;
				} else if (args.length-1 < 2*dim) {
					Serr("No size given.").newline;
					break;
				}

				Coords pos, size;
				if (!(
					readCoords( pos, args[1..1+dim]) &&
					readCoords(size, args[   1+dim..1+2*dim])
				))
					break;

				bool badSize = false;
				static if (dim >= 3) if (size.z <= 0) badSize = true;
				static if (dim >= 2) if (size.y <= 0) badSize = true;
				                     if (size.x <= 0) badSize = true;
				if (badSize) {
					Serr(
						"Cannot view rectangle with negative or zero side length."
					).newline;
					break;
				}

				state.space.binaryPut(Serr, pos, pos + size);
				Serr.newline;
				break;
			}

			// v (pos)
			case "v", "view": {
				if (args.length-1 < dim) {
					Serr("No position given.").newline;
					break;
				}

				Coords pos;
				if (!readCoords(pos, args[1..1+dim]))
					break;

				auto c = state.space[pos];

				Serr.format("Cell {}: value ", pos);
				printCell(c, "", NewlineString);
				break;
			}

			// e (pos) (val)
			case "e", "edit": {
				if (args.length-1 < dim) {
					Serr("No position given.").newline;
					break;
				} else if (args.length-1 < dim+1) {
					Serr("No value given.").newline;
					break;
				}

				Coords pos;
				if (!readCoords(pos, args[1..1+dim]))
					break;

				cell val;
				if (!readCell(val, args[1+dim]))
					break;

				state.space[pos] = val;

				Serr.format("Set cell {} to ", pos);
				printCell(val, "", NewlineString);
				break;
			}

		static if (!befunge93) {
			// w (ip)
			case "w", "switch": {
				if (args.length-1 < 1) {
					Serr("No IP given.").newline;
					break;
				}

				size_t idx;
				if (!readIpIndex(idx, args[1], invalidIndices))
					break;

				tip = ips[index = idx];
				Serr.formatln("Traced IP switched to IP {}.", idx);
				break;
			}
		}

			// p (pos) [ip]
			case "p", "position":
				ipSetVector(
					args, index, invalidIndices,
					"No position given.",
					"IP {} moved to {}.",
					function(IP ip, Coords c) { ip.pos = c; });
				break;

			// d (vec) [ip]
			case "d", "delta":
				ipSetVector(
					args, index, invalidIndices,
					"No delta given.",
					"Set delta of IP {} to {}.",
					function(IP ip, Coords c) { ip.delta = c; });
				break;

		static if (!befunge93) {
			// o (pos) [ip]
			case "o", "offset":
				ipSetVector(
					args, index, invalidIndices,
					"No offset given.",
					"Set offset of IP {} to {}.",
					function(IP ip, Coords c) { ip.offset = c; });
				break;
		}

			default:
				Serr.formatln(
					"Undefined command '{}'. See 'help' for a list of commands.",
					args[0]);
				break;
		}
	}
}

char[] arg(char[][] as, size_t i) { return i < as.length ? as[i] : null; }

void printCell(
	cell c,
	char[] pre = "",
	char[] post = "",
	char[] mid = " "
) {
	Serr.format("{}{1} 0x{1:x}{}'{}'{}", pre, c, mid, cast(char)c, post);
}

char[] stackString(in IP ip) {
	cell[8] onesToShow;

	size_t zeroes = 0;
	auto p = onesToShow.ptr;

	ip.stack.mapFirstNHead(onesToShow.length,
		(cell[] a) { p[0..a.length] = a; p += a.length; },
		(size_t n) { zeroes = n; });

	auto finalShow = onesToShow[0 .. p - onesToShow.ptr];

	char[] stackStr = "[".dup;

	while (zeroes--)
		stackStr ~= "  - ";

	foreach (c; finalShow)
		stackStr ~= Serr.layout.convert("{,3} ", c);

	stackStr[$-1] = ']';
	stackStr ~= ` "`;

	foreach (c; finalShow)
		stackStr ~= displayCell(c);

	stackStr ~= `"`;

	return stackStr;
}

char[] modeString(in IP ip) {
	char[] str = "       ".dup;
	size_t i = 0;

	if (ip.mode & IP.STRING)      str[i++] = '"';
	if (ip.mode & IP.HOVER)       str[i++] = 'H';

	static if (!befunge93) if (ip.stack.isDeque) {
		auto q = ip.stack.deque;
		if (q.mode & QUEUE_MODE)   str[i++] = 'Q';
		if (q.mode & INVERT_MODE)  str[i++] = 'I';
	}

	if (ip.mode & IP.SWITCH)      str[i++] = 'S';
	if (ip.mode & IP.DORMANT)     str[i++] = 'D';
	if (ip.mode & IP.FROM_FUTURE) str[i++] = 'T';

	return str;
}

void ipSetVector(
	char[][] args,
	size_t defaultIndex, bool[size_t] invalidIndices,
	char[] vecMissingMsg, char[] successMsg,
	void function(IP, Coords) f
) {
	if (args.length-1 < dim)
		return Serr(vecMissingMsg).newline;

	Coords vec;
	if (!readCoords(vec, args[1..1+dim]))
		return;

	auto idx = defaultIndex;
	readIpIndex(idx, args.arg(1+dim), invalidIndices);

	static if (befunge93)
		f(tip, vec);
	else
		f(state.ips[idx], vec);
	Serr.formatln(successMsg, idx, vec);
}

bool readIpIndex(inout size_t idx, char[] s, bool[size_t] invalidIndices) {
	static if (befunge93)
		return false;
	else {
		if (!s) return false;

		size_t i;
		if (!read(i, s) || i >= state.ips.length || i in invalidIndices) {
			Serr('\'')(s)("' is not a valid IP index.").newline;
			return false;
		}
		idx = i;
		return true;
	}
}

bool readIP(ref IP ip, ref size_t idx, char[] s, bool[size_t] invalidIndices) {
	static if (befunge93)
		return true;
	else {
		if (!s) return true;

		if (readIpIndex(idx, s, invalidIndices)) {
			ip = state.ips[idx];
			return true;
		}
		return false;
	}
}

bool readCoords(inout Coords c, char[][] args) {
	assert (args.length == dim);

	                     if (!read(cast(cell_base)c.x, args[0])) return false;
	static if (dim >= 2) if (!read(cast(cell_base)c.y, args[1])) return false;
	static if (dim >= 3) if (!read(cast(cell_base)c.z, args[2])) return false;

	return true;
}

bool read(T)(inout T n, char[] s) {
	try {
		     static if (isSignedIntegerType  !(T)) n = cast(T)parse  (s);
		else static if (isUnsignedIntegerType!(T)) n = cast(T)convert(s);
		else static assert (false, T.stringof);

		return true;
	} catch {
		Serr('\'')(s).format(
			"' is not a valid {} integer value.",
			(isSignedIntegerType!(T) ? "" : "un") ~ "signed"
		).newline;
		return false;
	}
}

bool readBool(inout bool b, char[] s) {
	if (!s) return true;
	if (!icompare(s, "true")  || s == "1") { b = true;  return true; }
	if (!icompare(s, "false") || s == "0") { b = false; return true; }

	Serr('\'')(s)("' is not a valid boolean value.").newline;
	return false;
}

bool readCell(inout cell v, char[] s) {
	if (!s) return true;

	if (s.length == 1) {
		v = cast(cell)s[0];
		return true;
	}

	return read(cast(cell_base)v, s);
}

char[] displayCell(cell c) {
	const CARET =
		['@', 'A', 'B', 'C', 'D', 'E',  'F', 'G', 'H', 'I', 'J'
		,'K', 'L', 'M', 'N', 'O', 'P',  'Q', 'R', 'S', 'T', 'U'
		,'V', 'W', 'X', 'Y', 'Z', '[', '\\', ']', '^', '_'];

	char[1] ch;
	char[2] s;

	ch[0] = cast(char)c;
	     if (ch[0] <= 0x1f) { s[0] = '^'; s[1] = CARET[ch[0]]; return s.dup; }
	else if (ch[0] == 0x7f) { s[0] = '^'; s[1] = '?';          return s.dup; }
	else return ch.dup;
}

}
