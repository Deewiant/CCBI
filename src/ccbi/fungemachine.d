// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2008-08-16 17:48:28

module ccbi.fungemachine;

debug import tango.core.tools.TraceExceptions;

import tango.core.Exception       : IOException, OutOfMemoryException;
import tango.core.Thread;
import tango.core.Tuple;
import tango.io.Console           : Cin;
import tango.io.Stdout;
import tango.io.device.Array      : Array;
import tango.io.stream.Buffered   : BufferedOutput;
import tango.io.stream.Format;
import tango.stdc.string          : memmove;
import tango.text.convert.Integer : format;

version (Posix) import tango.stdc.posix.signal;

import ccbi.container;
import ccbi.exceptions;
import ccbi.fingerprint;
import ccbi.flags;
import ccbi.fungestate;
import ccbi.ip;
import ccbi.request;
import ccbi.stats;
import ccbi.stdlib;
import ccbi.templateutils;
import ccbi.tracer;
import ccbi.utils;
import ccbi.fingerprints.all;
import ccbi.instructions.std;
import ccbi.instructions.templates;
import ccbi.space.space;

mixin (InsImports!());

private FormatOutput!(char) Sout, Serr;
static this() {
	Sout = new typeof(Sout)(
		Stdout.layout, new BufferedOutput(new RawCoutDevice!(false)));
	Serr = new typeof(Serr)(
		Stderr.layout, new BufferedOutput(new RawCoutDevice!(true )));

	Sin = new typeof(Sin)(Cin.stream);
}
static ~this() {
	// Tango only flushes tango.io.Console.{Cout,Cerr}
	// we capture output before it gets that far
	try {
		Sout.flush;
		Serr.flush;
	} catch {}
}

final class FungeMachine(cell dim, bool befunge93) {
	static assert (dim >= 1 && dim <= 3);
	static assert (!befunge93 || dim == 2);
private:
	static if (befunge93)
		alias Tuple!() fings;
	else
		alias ALL_FINGERPRINTS fings;

	alias .IP        !(dim, befunge93)* IP;
	alias .FungeSpace!(dim, befunge93)  FungeSpace;
	alias .Dimension !(dim).Coords      InitCoords;

	static if (!befunge93)
		IP tip; // traced IP

	static if (!befunge93)
		char[][] fungeArgs;

	int returnVal;

	Flags flags;
	Stats stats;
	ContainerStats stackStats, stackStackStats, dequeStats, semanticStats;

	IP cip;

	// Can't forward reference cip...
	static if (befunge93)
		alias cip tip;

	// Space is big: make sure it's last, to be nice to the cache.
	FungeState!(dim, befunge93) state;

	public this(Array source, char[][] args, Flags f) {
		flags = f;

		static if (!befunge93)
			fungeArgs = args;

		state.space = FungeSpace(&stats, source);
	}

	// Moved out of the constructor so that we can handle any initial
	// InfiniteLoopExceptions with the catch in run()
	void initialize() {
		auto pos = InitCoords!(0);

		static if (dim >= 2)
		if (
			flags.script &&
			state.space[InitCoords!(0,0)] == '#' &&
			state.space[InitCoords!(0,1)] == '!'
		)
		static if (befunge93)
			pos.y = 1;

		auto ip = IP.opCall(pos, &state.space, &stackStats);

		stats.newMax(stats.maxIpsLive, 1);

		static if (befunge93)
			tip = cip = ip;
		else {
			tip = ip;
			state.ips = typeof(state.ips)(ip);
		}

		version (Posix)
			signal(SIGPIPE, SIG_IGN);
	}

	public int run() {
		try {
			initialize();
			mainLoop: for (;;) {
				bool normalTime = true;

				static if (!befunge93)
					version (TRDS)
						normalTime = TRDS.isNormalTime();

				version (tracer)
					if (flags.tracing && !Tracer.doTrace())
						break mainLoop;

				static if (befunge93) {
					switch (executeInstruction()) {
						case Request.STOP: stop(); break mainLoop;
						case Request.MOVE: cip.move;
						default:           break;
					}
				} else {
					version (TRDS) if (state.useStartIt) {
						for (auto it = state.startIt; it.ok;) {
							switch (executeIP(normalTime, it)) {
								default:             break;
								case Request.QUIT:   break mainLoop;
								case Request.RETICK: continue mainLoop;
							}
						}
						state.useStartIt = false;
						goto tickDone;
					}
					for (auto it = state.ips.first; it.ok;) {
						switch (executeIP(normalTime, it)) {
							default:             break;
							case Request.QUIT:   break mainLoop;
							case Request.RETICK: continue mainLoop;
						}
					}
				}
			tickDone:
				if (normalTime) {
					static if (!befunge93)
						version (TRDS)
							if (usingTRDS)
								TRDS.newTick();

					     version (tracer) ++state.tick;
					else version (TRDS)   ++state.tick;
				}
			}
		} catch (OutOfMemoryException) {
			Sout.flush;
			Serr("CCBI :: Failed to allocate memory!").newline;
			returnVal = 3;

		} catch (InfiniteLoopException e) {
			if (flags.infiniteLoop)
				for (;;)
					// We're so fast we can run infinite loops without using the CPU
					Thread.yield();

			Sout.flush;
			Serr
				("CCBI :: Infinite loop detected!").newline()
				("  Detected by ")(e.detector)(':').newline()
				("    ")(e.toString).newline;
			returnVal = 2;

		} catch (Exception e) {
			Sout.flush;
			Serr
				("CCBI :: Exited due to an error!").newline()
				("  ")(e.toString).newline()
				("    at ")(e.file)(':')(e.line).newline;
			returnVal = 1;

			debug e.writeOut((char[] s) { Serr.print(s); });
		}

		version (statistics) if (flags.useStats) try {
			Sout.flush;
			printStats(Serr);
		} catch (IOException) {}
		return returnVal;
	}

	version (tracer)
		mixin .Tracer!() Tracer;

	// Semi-arbitrarily reuses Request to prevent having to make an enum just
	// for this...
	static if (!befunge93)
	Request executeIP(bool normalTime, inout typeof(state.ips).Iterator it) {
		if (!executable(normalTime, it.val)) {
			it++;
			return Request.NONE;
		}

		version (TRDS)
			TRDS.cipIt = it;

		cip = it.val;
		switch (executeInstruction()) {
			case Request.MOVE:
				cip.move();

			default:
				it++;
				return Request.NONE;

		static if (!befunge93) {
			case Request.FORK:
				state.ips.prependTo(it, cip);
				stats.newMax(stats.maxIpsLive, state.ips.length);
				goto case Request.MOVE;
		}

			case Request.STOP:
				if (!stop(it)) {
			case Request.QUIT:
					stats.ipStopped += state.ips.length;
					return Request.QUIT;
				}
				return Request.NONE;

		static if (!befunge93) version (TRDS) {
			case Request.RETICK:
				return Request.RETICK;
		}
		}
	}

	Request executeInstruction() {
		++stats.executionCount;

		cip.gotoNextInstruction();

		if (cip.mode & IP.STRING) {
			// In stringmode we might be at a space which is right next to a box,
			// but not in it.
			auto c = cip.cell;

			if (c == '"')
				cip.mode &= ~IP.STRING;
			else
				cip.stack.push(c);
			return Request.MOVE;
		}

		auto c = cip.unsafeCell;

		static if (!befunge93) if (!flags.allFingsDisabled) {
			version (IMAP)
				if (cast(ucell)c < cip.mapping.length)
					c = cip.mapping[c];

			if (isSemantics(c))
				return executeSemantics(c);
		}

		// Manually inline executeStandard here: we don't want to inline it in k
		// so we can't make it alwaysinline, and it's so big that it won't get
		// inlined otherwise.
		++stats.stdExecutionCount;

		switch (c) {
			mixin (Ins!("Std",
				befunge93 ? " !\"#$%&*+,-./0123456789:<>?@\\^_`gpv|~" :
				"!\"#$%&'()*+,-./0123456789:<=>?@\\_`abcdefgijknopqrstuxyz{}~" ~

				(dim >= 2 ? "[]^vw|" : "") ~
				(dim >= 3 ? "hlm"    : "")
			));
			default: unimplemented; break;
		}
		return Request.MOVE;
	}

	mixin StdInstructions!() Std;
	mixin Utils!();

	Request executeStandard(cell c) {
		++stats.stdExecutionCount;

		switch (c) {
			mixin (Ins!("Std",
				befunge93 ? " !\"#$%&*+,-./0123456789:<>?@\\^_`gpv|~" :

				// WORKAROUND: http://d.puremagic.com/issues/show_bug.cgi?id=1059
				"!\"#$%&'()*+,-./0123456789:<=>?@\\_`abcdefgijknopqrstuxyz{" ~

//				Range!('!', ':') ~ Range!('<', '@') ~ "\\" ~ Range!('_', 'g') ~
//				Range!('i', 'k') ~ Range!('n', 'u') ~        Range!('x', '{') ~
				"}~" ~

				(dim >= 2 ? "[]^vw|" : "") ~
				(dim >= 3 ? "hlm"    : "")
			));
			default: unimplemented; break;
		}
		return Request.MOVE;
	}

	static if (!befunge93) {
		mixin (ConcatMap!(TemplateMixin, ALL_FINGERPRINT_IDS));
		mixin (ConcatMap!(FingerprintCount, fings));

		char[] instructionsOf(cell fingerprint) {
			switch (fingerprint) {
				mixin (ConcatMap!(FingerprintInstructionsCase, fings));
				default: return null;
			}
		}

		void loadedFingerprint(cell fingerprint) {
			switch (fingerprint) {
				mixin (ConcatMap!(FingerprintConstructorCase, fings));
				default: break;
			}
		}
		void unloadedFingerprintIns(cell fingerprint) {
			switch (fingerprint) {
				mixin (ConcatMap!(FingerprintDestructorCase, fings));
				default: break;
			}
		}

		Request executeSemantics(cell c)
		in {
			assert (isSemantics(c));
		} body {
			++stats.fingExecutionCount;

			auto stack = cip.semantics[c - 'A'];
			if (!stack || stack.empty)
				return unimplemented;

			auto sem = stack.top;

			switch (sem.fingerprint) {
				mixin (FingerprintExecutionCases!(
					"sem.instruction",
					"assert (false, `Unknown instruction in semantic`);",
					fings));

				default: unimplemented; break;
			}

			return Request.MOVE;
		}
	}

	Request unimplemented() {
		++stats.unimplementedCount;

		if (flags.warnings) {
			auto i = cip.unsafeCell;
			warn(
				"Unimplemented instruction '{}' ({1:d}) (0x{1:x})"
				" encountered at {}.",
				cast(char)i, i, cip.pos.toString
			);
		}
		static if (!befunge93)
			reverse;
		return Request.MOVE;
	}

	bool stop(I...)(inout I it) {
		static if (befunge93) {
			static assert (I.length == 0);
			alias cip ip;
		} else {
			static assert (I.length == 1);
			static assert (is(typeof(it[0]) == typeof(state.ips).Iterator));
			auto ip = it[0].val;
		}

		version (tracer)
			Tracer.ipStopped(ip);

		static if (befunge93)
			return false;
		else {
			version (TRDS)
				if (usingTRDS)
					TRDS.ipStopped(ip);

			if (state.ips.length > 1) {
				it[0] = state.ips.removeAt(it[0]);

				if (ip.stackStack) {
					foreach (stack; *ip.stackStack) {
						stack.free();
						delete stack;
					}
					ip.stackStack.free();
					delete ip.stackStack;
				} else {
					ip.stack.free();
					delete ip.stack;
				}

				// Not in the below case because quitting handles that
				++stats.ipStopped;
				return true;
			} else
				return false;
		}
	}

	static if (!befunge93)
	bool executable(bool normalTime, IP ip) {
		if (state.ips.length == 1)
			return true;

		version (IIPC) if (flags.allFingsDisabled) return true;
		version (TRDS) if (flags.allFingsDisabled) return true;

		version (TRDS)
			if (usingTRDS && !TRDS.executable(normalTime, ip))
				return false;

		version (IIPC)
			if (!IIPC.executable(ip))
				return false;

		return true;
	}

	void warn(char[] fmt, ...) {
		Sout.flush;
		Serr("CCBI :: ");
		Serr.layout.convert(
			delegate uint(char[] s){ return Serr.write(s); },
			_arguments, _argptr, fmt);
		Serr.newline.flush;
	}

	version (statistics) void printStats(FormatOutput!(char) put) {
		put("============").newline;
		put(" Statistics" ).newline;
		put("============").newline;
		put.newline;

		struct Stat {
			char[] name;
			ulong n;
			char[] unit;
			char[] fin = "";
		}
		Stat[] ss;

		auto wasWere = stats.ipDormant == 1 ? "Was" : "Were";

		ss ~= Stat("Spent",                         state.tick+1,                  "tick");
		ss ~= Stat("Encountered",                   stats.executionCount,          "instruction");
		ss ~= Stat("Executed",                      stats.stdExecutionCount,       "standard instruction");
		ss ~= Stat("Executed",                      stats.fingExecutionCount,      "fingerprint instruction");
		ss ~= Stat("Encountered",                   stats.unimplementedCount,      "unimplemented instruction");
		ss ~= Stat("Spent in dormancy",             stats.execDormant,             "execution");
		ss ~= Stat(null);
		ss ~= Stat("Performed",                     stats.space.lookups,           "Funge-Space lookup");
		ss ~= Stat("Performed",                     stats.space.assignments,       "Funge-Space assignment");
		ss ~= Stat("Ended with",                    state.space.boxCount,          "AABB", "live");
		ss ~= Stat("Had",                           stats.space.maxBoxesLive,      "AABB", "live at maximum");
		ss ~= Stat("Incorporated",                  stats.space.boxesIncorporated, "AABB");
		ss ~= Stat("Placed",                        stats.space.boxesPlaced,       "AABB");
		ss ~= Stat("Subsumed",                      stats.space.subsumedContains,  "contained AABB");
		ss ~= Stat("Subsumed",                      stats.space.subsumedDisjoint,  "disjoint AABB");
		ss ~= Stat("Subsumed",                      stats.space.subsumedFusables,  "fusable AABB");
		ss ~= Stat("Subsumed",                      stats.space.subsumedOverlaps,  "overlapping AABB");
		ss ~= Stat("Dropped",                       stats.space.emptyBoxesDropped, "empty AABB");
		ss ~= Stat(null);
		ss ~= Stat("Pushed onto stack",             stackStats.pushes,             "cell");
		ss ~= Stat("Popped from stack",             stackStats.pops,               "cell");
		ss ~= Stat("Cleared from stack",            stackStats.cleared,            "cell");
		ss ~= Stat("Peeked stack",                  stackStats.peeks,              "time");
		ss ~= Stat("Cleared stack",                 stackStats.clears,             "time");
		ss ~= Stat("Underflowed stack during pop",  stackStats.popUnderflows,      "time");
		ss ~= Stat("Underflowed stack during peek", stackStats.peekUnderflows,     "time");
		ss ~= Stat("Resized stack",                 stackStats.resizes,            "time");
		ss ~= Stat("Stack contained",               stackStats.maxSize,            "cell", "at maximum");
		ss ~= Stat(null);
		ss ~= Stat("Pushed onto deque",             dequeStats.pushes,             "cell");
		ss ~= Stat("Popped from deque",             dequeStats.pops,               "cell");
		ss ~= Stat("Cleared from deque",            dequeStats.cleared,            "cell");
		ss ~= Stat("Peeked deque",                  dequeStats.peeks,              "time");
		ss ~= Stat("Cleared deque",                 dequeStats.clears,             "time");
		ss ~= Stat("Underflowed deque during pop",  dequeStats.popUnderflows,      "time");
		ss ~= Stat("Underflowed deque during peek", dequeStats.peekUnderflows,     "time");
		ss ~= Stat("Resized deque",                 dequeStats.resizes,            "time");
		ss ~= Stat("Deque contained",               dequeStats.maxSize,            "cell", "at maximum");
		ss ~= Stat(null);
		ss ~= Stat("Pushed onto stack stack",       stackStackStats.pushes,        "container");
		ss ~= Stat("Popped from stack stack",       stackStackStats.pops,          "container");
		ss ~= Stat("Cleared from stack stack",      stackStackStats.cleared,       "container");
		ss ~= Stat("Peeked stack stack",            stackStackStats.peeks,         "time");
		ss ~= Stat("Cleared stack stack",           stackStackStats.clears,        "time");
		ss ~= Stat("Resized stack stack",           stackStackStats.resizes,       "time");
		ss ~= Stat("Stack stack contained",         stackStackStats.maxSize,       "stack", "at maximum");
		ss ~= Stat(null);
		ss ~= Stat("Pushed onto semantic stack",    semanticStats.pushes,          "semantic");
		ss ~= Stat("Popped from semantic stack",    semanticStats.pops,            "semantic");
		ss ~= Stat("Cleared from semantic stack",   semanticStats.cleared,         "semantic");
		ss ~= Stat("Peeked semantic stack",         semanticStats.peeks,           "time");
		ss ~= Stat("Cleared semantic stack",        semanticStats.clears,          "time");
		ss ~= Stat("Resized semantic stack",        semanticStats.resizes,         "time");
		ss ~= Stat("Any semantic stack contained",  semanticStats.maxSize,         "semantic", "at maximum");
		ss ~= Stat(null);
		ss ~= Stat("Forked",                        stats.ipForked,                "IP");
		ss ~= Stat("Stopped",                       stats.ipStopped,               "IP");
		ss ~= Stat("Had",                           stats.maxIpsLive,              "IP", "live at maximum");
		ss ~= Stat(wasWere ~ " dormant",            stats.ipDormant,               "IP");
		ss ~= Stat("Travelled to the past",         stats.ipTravelledToPast,       "IP");
		ss ~= Stat("Travelled to the future",       stats.ipTravelledToFuture,     "IP");
		ss ~= Stat("Arrived in the past",           stats.travellerArrived,        "IP");
		ss ~= Stat(null);
		ss ~= Stat("Stopped time",                  stats.timeStopped,             "time");

		char[20] buf;
		size_t wideName = 0, wideN = 0;
		foreach (stat; ss)
		if (stat.name !is null && stat.n) {
			uint width = cast(uint).format!(char,ulong)(buf, stat.n).length;
			if (width > wideN)
				wideN = width;
			if (stat.name.length > wideName)
				wideName = stat.name.length;
		}

		auto fmt = "{," ~ .format!(char,ulong)(buf, wideN) ~ ":} ";
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

			put.format(fmt, stat.n)(stat.unit);
			if (stat.n != 1)
				put('s');

			if (stat.fin.length)
				put(' ')(stat.fin);

			put.newline;
		}
	}
}
