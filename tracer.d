// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2006-06-14 11:52:53

// The tracing facilities.
module ccbi.tracer;

// WORKAROUND: http://www.dsource.org/projects/dsss/ticket/175
import tango.text.Ascii;

// TODO: put "Tracer ::" prompt in a func of its own
// so that it can print "Tracer 1 ::" when in MVRS!

template Tracer() {

import tango.core.Traits          : isSignedIntegerType, isUnsignedIntegerType;
import tango.io.Console           : Cin;
import tango.math.Math            : min;
import tango.text.convert.Integer : parse, convert;
import tango.text.Ascii           : toLower;
import tango.text.Util            : split;

import ccbi.container;
import ccbi.ip;
import ccbi.space;
import ccbi.stdlib;

alias .Coords!(dim) Coords;
alias .IP    !(dim) IP;

bool stopNext = true;

byte[IP][Coords      ]  bps; //      breakpoints
bool[IP][cell        ] cbps; // cell breakpoints
byte    [typeof(tick)] tbps; // tick breakpoints

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

bool doTrace() {
	const DEBUGHELP =
"A parameter enclosed in () is necessary, [] denotes optionality.
Where an IP parameter is optional, the default is the traced IP unless
otherwise specified.

(h)elp
	Show this help text
e(x)plain
	Explains the meaning of the mode string

i(n)fo [ip]
	Show the short info displayed after every step
(i)ps
	Show information about each active IP
s(w)itch (ip)
	Switch tracing to a different IP

(s)tep
	Step one instruction
(r)un
	Continue execution until any IP hits a breakpoint

(b)reak (pos) [ip]
	Toggle a breakpoint, applies to all IPs by default
(c)break (value) [strmode boolean] [ip]
	Toggle a cell breakpoint, doesn't apply in stringmode by default, applies to
	all IPs by default
de(l)ay (tick)
	Toggle a tick breakpoint
bs, bps [ip]
	Show a list of all breakpoints affecting IP, or all if not given

s(t)ack [ip]
	Show the stack(s) of an IP
(a)rea (pos) (size)
	Show an area of Funge-Space
(v)iew (pos)
	Show the value of a cell in Funge-Space
(e)dit (pos) (val)
	Set  the value of a cell in Funge-Space

(p)osition (pos) [ip]
	Set the position of the current IP
(d)elta (vec) [ip]
	Set the delta of the current IP
(o)ffset (pos) [ip]
	Set the storage offset of the current IP

(k)ill [ip]
	Kill an IP
(q)uit
	Quit the program"
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

	void printIP(size_t i, IP ip) {
		Serr("Tracer :: ");
		if (ips.length > 1)
			Serr.format("IP {}, with ID {}, ", i, ip.id);
		else
			Serr("The IP ");
	}

	Sout.flush();

	bool atBreak = false;
	size_t breaker = void;

	foreach (pos, ipSet; bps)
	foreach (i, ip; ips)
	if (
		(null in ipSet || ip in ipSet) &&
		ip.pos == pos
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
			space[ip.pos] == val
		) {
			atBreak = true;

			printIP(i, ip);
			printCell(val, "hit the cell breakpoint for ", "." ~ NewlineString);
		}
	}

	foreach (bp, ignored; tbps)
	if (tick == bp) {
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

	foreach (i, ip; ips)
	if (tick < ip.jumpedTo) {
		--ipCount;
		invalidIndices[i] = true;
	} else if (i < minimalValid)
		minimalValid = i;

	if (tip) {
		foreach (i, ip; ips)
		if (tip is ip) {
			index = i;
			break;
		}
	} else {
		Serr.formatln(
			"Switched traced IP to IP {} since the previous IP {} disappeared.",
			minimalValid, index);

		tip = ips[index = minimalValid];
		Serr.formatln("New traced IP has ID {}.", tip.id);
	}

	void showInfo(IP ip) {
		auto i = space[ip.pos];
		printCell(i, NewlineString ~ "Instruction: ", NewlineString);
		Serr.formatln(
			"Position: {} -- Delta: {} -- Offset: {}",
			ip.pos, ip.delta, ip.offset);
		Serr.formatln("Stack: {} cell(s): {}", ip.stack.size, stackString(ip));

		Serr.formatln(
			"Tick: {} -- IPs: {} -- Index/ID: {}/{} -- Stacks: {} -- Mode: {}"
			~ NewlineString,
			tick, ipCount, index, ip.id, ip.stackStack.size, modeString(ip));
	}

	showInfo(tip);

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
		foreach (arg; args)
			toLower(arg);

		switch (args[0]) {
			case "h", "hlp", "?", "help": Serr(DEBUGHELP ).newline; break;
			case "x", "explain":          Serr(MODESTRING).newline; break;
			case "s", "step":                   return true;
			case "r", "run" : stopNext = false; return true;

			// k [ip]
			case "k", "kill":
				auto idx = index;
				if (!readIpIndex(idx, args.arg(1), invalidIndices))
					break;

				Serr.formatln("Successfully killed IP {}.", idx);
				return stop(idx);

			case "q", "quit", ":q": return false;

			// n [ip]
			case "n", "info":
				auto ip = tip;
				readIP(ip, args.arg(1), invalidIndices);
				showInfo(ip);
				break;

			// bs [ip]
			case "bs", "bps":
				if (!bps.length && !cbps.length && !tbps.length) {
					Serr("No breakpoints.").newline;
					break;
				}

				IP ip = null;
				size_t idx;
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
						else
							Serr(ips.findIndex(i));
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
						else
							Serr(ips.findIndex(i));
						Serr(stringsAlso ? ",1" : ",0");
					}
					Serr.newline;
				}
				foreach (time, ignored; tbps)
					Serr("Tick ")(time).newline;

				break;

			case "i", "ips":
				Serr.formatln("{} IPs, in reverse order of execution:", ipCount);
				foreach (i, ip; ips)
				if (tick >= ip.jumpedTo) {

					char[] str = "[".dup;
					foreach (st; &ip.stackStack.bottomToTop)
						str ~= Serr.layout.convert("{} ", st.size);
					str[$-1] = ']';

					Serr.format(
						" IP {,2:} -- Position: {} - Delta: {} - Offset: {}"
						~ NewlineString ~
						"          ID: {} - Mode: {}"
						~ NewlineString ~
						"          Stack number/sizes: {}/{}"
						~ NewlineString ~
						"          Instruction: ",
						i, ip.pos, ip.delta, ip.offset,
						ip.id, modeString(ip),
						ip.stackStack.size, str
					);
					printCell(space[ip.pos], "", NewlineString~NewlineString, " ");
				}
				break;

			// b (pos) [ip]
			case "b", "bp", "break":
				if (args.length-1 < dim) {
					Serr("No position given.").newline;
					break;
				}

				Coords pos;
				if (!readCoords(pos, args[1..1+dim]))
					break;

				size_t idx;
				IP ip = null;
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

			// c (val) [strings] [ip]
			case "c", "cbp", "cbreak":
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

			// l (tick)
			case "l", "tbp", "delay":
				if (args.length < 2) {
					Serr("No tick given.").newline;
					break;
				}

				typeof(tick) tb;
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

			// t [ip]
			case "t", "stack":
				auto ip = tip;
				readIP(ip, args.arg(1), invalidIndices);

				Serr(ip.stackStack.size)(" stack(s):").newline;

				size_t i = 1;
				foreach (st; &ip.stackStack.topToBottom) {
					auto n = st.size;
					Serr.format(" Stack {,2:}, {,4:} element(s):", i++, n)(" [");
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
				Serr.newline;
				break;

			// a (pos) (size)
			case "a", "area":
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

				auto posE = pos.extend(0);
				auto end = posE; end += size.extend(1);

				space.binaryPut(Serr, posE, end);
				break;

			// v (pos)
			case "v", "view":
				if (args.length-1 < dim) {
					Serr("No position given.").newline;
					break;
				}

				Coords pos;
				if (!readCoords(pos, args[1..1+dim]))
					break;

				auto c = space[pos];

				Serr.format("Cell {}: value ", pos);
				printCell(c, "", NewlineString);
				break;

			// e (pos) (val)
			case "e", "edit":
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

				space[pos] = val;

				Serr.format("Set cell {} to ", pos);
				printCell(val, "", NewlineString);
				break;

			// w (ip)
			case "w", "switch":
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

			// o (pos) [ip]
			case "o", "offset":
				ipSetVector(
					args, index, invalidIndices,
					"No offset given.",
					"Set offset of IP {} to {}.",
					function(IP ip, Coords c) { ip.offset = c; });
				break;

			default:
				Serr.formatln(
					"Undefined command '{}'. See 'help' for a list of commands.",
					args[0]);
				break;
		}
	}

	return true;
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
	auto numShown = min(ip.stack.size, onesToShow.length);

	for (auto i = numShown; i--;)
		onesToShow[$-i-1] = ip.stack.popHead;

	auto finalShow = onesToShow[$-numShown..$].reverse;

	ip.stack.pushHead(finalShow);

	assert (ip.stack.size >= numShown);

	char[] stackStr = "[".dup;

	for (size_t j = 0; j < onesToShow.length - numShown; ++j)
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
	char[] str = "      ".dup;
	size_t i = 0;

	if (ip.mode & IP.STRING)      str[i++] = '"';

	if (ip.mode & IP.HOVER)       str[i++] = 'H';

	auto q = cast(Deque)ip.stack;
	if (q) {
		if (q.mode & QUEUE_MODE)   str[i++] = 'Q';
		if (q.mode & INVERT_MODE)  str[i++] = 'I';
	}

	if (ip.mode & IP.SWITCH)      str[i++] = 'S';

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

	f(ips[idx], vec);
	Serr.formatln(successMsg, idx, pos);
}

bool readIpIndex(inout size_t idx, char[] s, bool[size_t] invalidIndices) {
	if (!s) return false;
	try {
		size_t i;
		if (!read(i, s) || i >= ips.length || i in invalidIndices)
			throw new Object;
		idx = i;
		return true;

	} catch {
		Serr('\'')(s)("' is not a valid IP index.").newline;
		return false;
	}
}

bool readIP(inout IP ip, char[] s, bool[size_t] invalidIndices) {
	if (!s) return false;

	size_t idx;
	if (readIpIndex(idx, s, invalidIndices)) {
		ip = ips[idx];
		return true;
	} else
		return false;
}

bool readCoords(inout Coords c, char[][] args) {
	assert (args.length == dim);

	                     if (!read(cast(cell_base)c.x, args[0])) return false;
	static if (dim >= 2) if (!read(cast(cell_base)c.y, args[0])) return false;
	static if (dim >= 3) if (!read(cast(cell_base)c.z, args[0])) return false;

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
	if (s == "true"  || s == "1") { b = true;  return true; }
	if (s == "false" || s == "0") { b = false; return true; }

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
