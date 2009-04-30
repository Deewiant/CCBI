// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2008-08-16 17:48:28

module ccbi.fungemachine;

import tango.core.Tuple;
import tango.io.Stdout;
import tango.io.device.File     : File;
import tango.io.stream.Buffered : BufferedOutput;
import tango.io.stream.Format;
import tango.io.stream.Typed;
import tango.text.convert.Integer : toString;

import ccbi.container;
import ccbi.fingerprint;
import ccbi.flags;
import ccbi.ip;
import ccbi.request;
import ccbi.space;
import ccbi.stats;
import ccbi.stdlib;
import ccbi.templateutils;
import ccbi.tracer;
import ccbi.utils;
import ccbi.fingerprints.all;
import ccbi.instructions.std;
import ccbi.instructions.templates;

mixin (InsImports!());

// Essentially the only difference in Mini-Funge is the loading, since one has
// to deal with the =FOO commands
//
// Other than that, have an executeMiniFunge to handle the differences

private  TypedOutput!(ubyte) Cout;
private FormatOutput!(char)  Sout, Serr;
static this() {
	Sout = new typeof(Sout)(
		Stdout.layout, new BufferedOutput(new RawCoutFilter!(false), 32*1024));
	Serr = new typeof(Serr)(
		Stderr.layout, new BufferedOutput(new RawCoutFilter!(true ), 32*1024));

	Cout = new typeof(Cout)(Sout.stream);
}
static ~this() {
	// Tango only flushes tango.io.Console.{Cout,Cerr}
	// we capture output before it gets that far
	Sout.flush;
	Serr.flush;
}

final class FungeMachine(cell dim, bool befunge93) {
	static assert (dim >= 1 && dim <= 3);
	static assert (!befunge93 || dim == 2);
private:
	static if (befunge93)
		alias Tuple!() fings;
	else
		alias ALL_FINGERPRINTS fings;

	alias .IP        !(dim, befunge93, fings) IP;
	alias .FungeSpace!(dim, befunge93)        FungeSpace;
	alias .Dimension !(dim).Coords            InitCoords;

	mixin (EmitGot!("IIPC", fings));
	mixin (EmitGot!("IMAP", fings));
	mixin (EmitGot!("TRDS", fings));

	IP[] ips;
	IP   cip;
	IP   tip; // traced IP
	FungeSpace space;

	// For IPs
	cell currentID = 0;

	char[][] fungeArgs;

	// TRDS pretty much forces this to be signed (either that or handle signed
	// time displacements manually)
	long tick = 0;

	int returnVal;

	Flags flags;
	Stats stats;
	ContainerStats stackStats, stackStackStats, dequeStats, semanticStats;

	public this(File source, char[][] args, Flags f) {
		flags = f;
		fungeArgs = args;

		static if (GOT_TRDS)
			alias TRDS.initialSpace firstSpace;
		else
			alias space firstSpace;

		firstSpace = new FungeSpace(&stats, source);

		ips.length = 1;
		reboot();
	}

	void reboot() {
		static if (GOT_TRDS) {
			if (flags.fingerprintsEnabled)
				space = new typeof(space)(initialSpace);
			else
				space = initialSpace;
		}

		tip = ips[0] = new IP(
			space, &stackStats, &stackStackStats, &dequeStats, &semanticStats);

		if (
			dim >= 2     &&
			flags.script &&
			space[InitCoords!(0,0)] == '#' &&
			space[InitCoords!(0,1)] == '!'
		)
			ips[0].pos.y = 1;
	}

	public int run() {
		try while (executeTick) {}
		catch (Exception e) {
			Sout.flush;
			Serr
				("Exited due to an error: ")(e.msg)
				(" at ")(e.file)(':')(e.line)
				.newline;
			returnVal = 1;
		}

		if (flags.useStats) {
			Sout.flush;
			printStats(Serr);
		}
		return returnVal;
	}

	bool executeTick() {
		static if (GOT_TRDS)
			bool normalTime = TRDS.isNormalTime();
		else
			const bool normalTime = true;

		if (flags.tracing && !Tracer.doTrace())
			return false;

		for (auto j = ips.length; j-- > 0;)
		if (executable(normalTime, ips[j])) {

			cip = ips[j];
			switch (executeInstruction()) {

				case Request.STOP:
					if (!stop(j)) {
				case Request.QUIT:
						stats.ipStopped += ips.length;
						return false;
					}
					break;

			static if (GOT_TRDS) {
				case Request.TIMEJUMP:
					TRDS.timeJump(cip);
					return true;
			}

				case Request.MOVE:
					cip.move();

				default: break;
			}

			Sout.flush;
			Serr.flush;
		}
		if (normalTime) {
			++tick;

			static if (GOT_TRDS)
				TRDS.newTick();
		}
		return true;
	}

	mixin .Tracer!() Tracer;

	Request executeInstruction() {
		++stats.executionCount;

		static if (!befunge93)
			cip.gotoNextInstruction();

		auto c = space[cip.pos];

		if (c == '"')
			cip.mode ^= IP.STRING;
		else if (cip.mode & IP.STRING)
			cip.stack.push(c);
		else {
			static if (!befunge93) if (flags.fingerprintsEnabled) {
				static if (GOT_IMAP) {
					if (c >= 0 && c < cip.mapping.length) {
						c = cip.mapping[c];

						// Semantics are all in the range ['A','Z'], so since this
						// assert succeeds the isSemantics check can be inside this
						// if statement.
						static assert (cip.mapping.length > 'Z');

						if (isSemantics(c))
							return executeSemantics(c);
					}
				} else if (isSemantics(c))
					return executeSemantics(c);
			}

			return executeStandard(c);
		}
		return Request.MOVE;
	}

	mixin StdInstructions!() Std;
	mixin Utils!();

// TODO: move dim information to instructions themselves, since fingerprints
// need it as well
	Request executeStandard(cell c) {
		++stats.stdExecutionCount;

		switch (c) mixin (Switch!(
			Ins!("Std",
				befunge93 ? " !\"#$%&*+,-./0123456789:<>?@\\^_`gpv|~" :

				// WORKAROUND: http://d.puremagic.com/issues/show_bug.cgi?id=1059
				"!\"#$%&'()*+,-./0123456789:<=>?@\\_`abcdefgijknopqrstuxyz{" ~

//				Range!('!', ':') ~ Range!('<', '@') ~ "\\" ~ Range!('_', 'g') ~
//				Range!('i', 'k') ~ Range!('n', 'u') ~        Range!('x', '{') ~
				"}~" ~

				(dim >= 2 ? "[]^vw|" : "") ~
				(dim >= 3 ? "hlm"    : "")
			),

			"default: unimplemented; break;"
		));
		return Request.MOVE;
	}

	static if (!befunge93) {
		mixin (ConcatMapTuple!(TemplateMixin, MapTuple!(PrefixName, fings))); 
		mixin (ConcatMapTuple!(FingerprintCount, fings));

		void loadedFingerprint(cell fingerprint) {
			switch (fingerprint) mixin (Switch!(
				FingerprintConstructorCases!(fings),
				"default: break;"
			));
		}
		void unloadedFingerprintIns(cell fingerprint) {
			switch (fingerprint) mixin (Switch!(
				FingerprintDestructorCases!(fings),
				"default: break;"
			));
		}

		Request executeSemantics(cell c)
		in {
			assert (isSemantics(c));
		} body {
			++stats.fingExecutionCount;

			auto stack = cip.semantics[c - 'A'];
			if (stack.empty)
				return unimplemented;

			auto sem = stack.top;

			switch (sem.fingerprint) mixin (Switch!(
				// foreach fing, generates the following:
				// case HexCode!(fing):
				// 	switch (sem.instruction) mixin (Switch!(
				// 		mixin (Ins!(fing, Range!('A', 'Z'))),
				// 		"default: assert (false);"
				// 	));

				FingerprintExecutionCases!(
					"sem.instruction",
					"assert (false);",
					fings),
				"default: unimplemented; break;"
			));

			return Request.MOVE;
		}
	}

	Request unimplemented() {
		++stats.unimplementedCount;

		if (flags.warnings) {
			Sout.flush;
			// XXX: this looks like a hack
//			if (inMini)
//				miniUnimplemented();
/+			else +/ {
				auto i = space[cip.pos];
				warn(
					"Unimplemented instruction '{}' ({1:d}) (0x{1:x})"
					" encountered at {}.",
					cast(char)i, i, cip.pos.toString
				);
			}
		}
		reverse;
		return Request.MOVE;
	}

	bool stop(size_t idx) {
		auto ip = ips[idx];

		Tracer.ipStopped(ip);

		if (flags.fingerprintsEnabled)
			static if (GOT_TRDS)
				TRDS.ipStopped(ip);

		ips.removeAt(idx);

		if (ips.length > 0) {
			// Not in the below case because quitting handles that
			++stats.ipStopped;
			return true;
		} else
			return false;
	}

	bool executable(bool normalTime, IP ip) {
		if (ips.length == 1)
			return true;

		static if (GOT_TRDS || GOT_IIPC) {
			if (!flags.fingerprintsEnabled)
				return true;
		}

		static if (GOT_TRDS) {
			if (!TRDS.executable(normalTime, ip))
				return false;
		}
		static if (GOT_IIPC) {
			if (!IIPC.executable(ip))
				return false;
		}
		return true;
	}

	void warn(char[] fmt, ...) {
		Serr.layout.convert(
			delegate uint(char[] s){ return Serr.write(s); },
			_arguments, _argptr, fmt);
	}

	void printStats(FormatOutput!(char) put) {
		put("============").newline;
		put(" Statistics ").newline;
		put("============").newline;
		put.newline;

		struct Stat {
			char[] name;
			ulong n;
			char[] fin;
		}
		Stat[] ss;

		auto wasWere = stats.ipDormant == 1 ? "Was" : "Were";

		ss ~= Stat("Spent",                         tick+1,                    "tick");
		ss ~= Stat("Encountered",                   stats.executionCount,      "instruction");
		ss ~= Stat("Executed",                      stats.stdExecutionCount,   "standard instruction");
		ss ~= Stat("Executed",                      stats.fingExecutionCount,  "fingerprint instruction");
		ss ~= Stat("Encountered",                   stats.unimplementedCount,  "unimplemented instruction");
		ss ~= Stat("Spent in dormancy",             stats.execDormant,         "execution");
		ss ~= Stat(null);
		ss ~= Stat("Performed",                     stats.spaceLookups,        "Funge-Space lookup");
		ss ~= Stat("Performed",                     stats.spaceAssignments,    "Funge-Space assignment");
		ss ~= Stat(null);
		ss ~= Stat("Pushed onto stack",             stackStats.pushes,         "cell");
		ss ~= Stat("Popped from stack",             stackStats.pops,           "cell");
		ss ~= Stat("Cleared from stack",            stackStats.cleared,        "cell");
		ss ~= Stat("Peeked stack",                  stackStats.peeks,          "time");
		ss ~= Stat("Cleared stack",                 stackStats.clears,         "time");
		ss ~= Stat("Underflowed stack during pop",  stackStats.popUnderflows,  "time");
		ss ~= Stat("Underflowed stack during peek", stackStats.peekUnderflows, "time");
		ss ~= Stat("Resized stack",                 stackStats.resizes,        "time");
		ss ~= Stat(null);
		ss ~= Stat("Pushed onto deque",             dequeStats.pushes,         "cell");
		ss ~= Stat("Popped from deque",             dequeStats.pops,           "cell");
		ss ~= Stat("Cleared from deque",            dequeStats.cleared,        "cell");
		ss ~= Stat("Peeked deque",                  dequeStats.peeks,          "time");
		ss ~= Stat("Cleared deque",                 dequeStats.clears,         "time");
		ss ~= Stat("Underflowed deque during pop",  dequeStats.popUnderflows,  "time");
		ss ~= Stat("Underflowed deque during peek", dequeStats.peekUnderflows, "time");
		ss ~= Stat("Resized deque",                 dequeStats.resizes,        "time");
		ss ~= Stat(null);
		ss ~= Stat("Pushed onto stack stack",       stackStackStats.pushes,    "container");
		ss ~= Stat("Popped from stack stack",       stackStackStats.pops,      "container");
		ss ~= Stat("Cleared from stack stack",      stackStackStats.cleared,   "container");
		ss ~= Stat("Peeked stack stack",            stackStackStats.peeks,     "time");
		ss ~= Stat("Cleared stack stack",           stackStackStats.clears,    "time");
		ss ~= Stat("Resized stack stack",           stackStackStats.resizes,   "time");
		ss ~= Stat(null);
		ss ~= Stat("Pushed onto semantic stack",    semanticStats.pushes,      "semantic");
		ss ~= Stat("Popped from semantic stack",    semanticStats.pops,        "semantic");
		ss ~= Stat("Cleared from semantic stack",   semanticStats.cleared,     "semantic");
		ss ~= Stat("Peeked semantic stack",         semanticStats.peeks,       "time");
		ss ~= Stat("Cleared semantic stack",        semanticStats.clears,      "time");
		ss ~= Stat("Resized semantic stack",        semanticStats.resizes,     "time");
		ss ~= Stat(null);
		ss ~= Stat("Forked",                        stats.ipForked,            "IP");
		ss ~= Stat("Stopped",                       stats.ipStopped,           "IP");
		ss ~= Stat(wasWere ~ " dormant",            stats.ipDormant,           "IP");
		ss ~= Stat("Travelled to the past",         stats.ipTravelledToPast,   "IP");
		ss ~= Stat("Travelled to the future",       stats.ipTravelledToFuture, "IP");
		ss ~= Stat("Arrived in the past",           stats.travellerArrived,    "IP");
		ss ~= Stat(null);
		ss ~= Stat("Stopped time",                  stats.timeStopped,         "time");

		size_t wideName = 0, wideN = 0;
		foreach (stat; ss)
		if (stat.name !is null && stat.n) {
			uint width = .toString(stat.n).length;
			if (width > wideN)
				wideN = width;
			if (stat.name.length > wideName)
				wideName = stat.name.length;
		}

		auto fmt = "{," ~ .toString(wideN) ~ ":d} ";
		bool newline = false;

		foreach (stat; ss)
		if (stat.name is null)
			newline = true;
		else if (stat.n) {
			if (newline) {
				newline = false;
				put.newline;
			}
			put(stat.name)(':');

			for (auto i = stat.name.length; i <= wideName; ++i)
				put(' ');

			put.format(fmt, stat.n)(stat.fin);
			if (stat.n != 1)
				put('s');

			put.newline;
		}
	}
}
