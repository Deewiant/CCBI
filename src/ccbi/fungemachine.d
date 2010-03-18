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
		Stdout.layout, new BufferedOutput(new RawCoutFilter!(false), 32*1024));
	Serr = new typeof(Serr)(
		Stderr.layout, new BufferedOutput(new RawCoutFilter!(true ), 32*1024));

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

	mixin (EmitGot!("IIPC", fings));
	mixin (EmitGot!("IMAP", fings));
	mixin (EmitGot!("TRDS", fings));

	IP cip;
	FungeState!(dim, befunge93) state;

	static if (!befunge93)
		IP tip; // traced IP
	else
		alias cip tip;

	static if (!befunge93)
		char[][] fungeArgs;

	int returnVal;

	Flags flags;
	Stats stats;
	ContainerStats stackStats, stackStackStats, dequeStats, semanticStats;

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

		static if (befunge93)
			tip = cip = ip;
		else {
			state.startIdx = state.ips.length = 1;
			tip = state.ips[0] = ip;
		}

		version (Posix)
			signal(SIGPIPE, SIG_IGN);
	}

	public int run() {
		try {
			initialize();
			mainLoop: for (;;) {
				static if (GOT_TRDS)
					bool normalTime = TRDS.isNormalTime();
				else
					const bool normalTime = true;

				version (tracer)
					if (flags.tracing && !Tracer.doTrace())
						break mainLoop;

				static if (befunge93) {
					switch (executeInstruction()) {
						case Request.STOP: stop(0); break mainLoop;
						case Request.MOVE: cip.move;
						default:           break;
					}
				} else for (auto j = state.startIdx; j-- > 0;)
				if (executable(normalTime, state.ips[j])) {

					static if (GOT_TRDS)
						TRDS.cipIdx = j;

					cip = state.ips[j];
					switch (executeInstruction()) {

						case Request.MOVE:
							cip.move();

						default: break;

						case Request.FORK:
							if (j < state.ips.length-2) {
								// ips[$-1] is new and in the wrong place, position it
								// immediately after this one
								auto ip = state.ips[$-1];
								memmove(
									&state.ips[j+2], &state.ips[j+1],
									(state.ips.length - (j+1)) * ip.sizeof);
								state.ips[j+1] = ip;
							}
							goto case Request.MOVE;

						case Request.STOP:
							if (!stop(j)) {
						case Request.QUIT:
								stats.ipStopped += state.ips.length;
								break mainLoop;
							}
							break;

					static if (GOT_TRDS) {
						case Request.RETICK:
							continue mainLoop;
					}
					}
				}
				static if (!befunge93)
					state.startIdx = state.ips.length;

				if (normalTime) {
					static if (GOT_TRDS)
						if (usingTRDS)
							TRDS.newTick();

					++state.tick;
				}
			}
		} catch (OutOfMemoryException) {
			Sout.flush;
			Serr("CCBI :: Failed to allocate memory!").newline;
			returnVal = 3;

		} catch (InfiniteLoopException e) {
			if (!flags.detectInfiniteLoops)
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

	Request executeInstruction() {
		++stats.executionCount;

		cip.gotoNextInstruction();

		auto c = cip.unsafeCell;

		if (c == '"')
			cip.mode ^= IP.STRING;
		else if (cip.mode & IP.STRING)
			cip.stack.push(c);
		else {
			static if (!befunge93) if (!flags.allFingsDisabled) {
				static if (GOT_IMAP)
					if (c < cip.mapping.length && c >= 0)
						c = cip.mapping[c];

				if (isSemantics(c))
					return executeSemantics(c);
			}

			return executeStandard(c);
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
			if (stack.empty)
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
			Sout.flush;
			auto i = cip.unsafeCell;
			warn(
				"Unimplemented instruction '{}' ({1:d}) (0x{1:x})"
				" encountered at {}.",
				cast(char)i, i, cip.pos.toString
			);
		}
		reverse;
		return Request.MOVE;
	}

	bool stop(size_t idx) {

		static if (befunge93)
			alias cip ip;
		else
			auto ip = state.ips[idx];

		version (tracer)
			Tracer.ipStopped(ip);

		static if (GOT_TRDS)
			if (usingTRDS)
				TRDS.ipStopped(ip);

		static if (befunge93)
			return false;
		else {
			if (state.ips.length > 1) {
				state.ips.removeAt(idx);

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

		static if (GOT_TRDS || GOT_IIPC)
			if (flags.allFingsDisabled)
				return true;

		static if (GOT_TRDS)
			if (usingTRDS && !TRDS.executable(normalTime, ip))
				return false;

		static if (GOT_IIPC)
			if (!IIPC.executable(ip))
				return false;

		return true;
	}

	void warn(char[] fmt, ...) {
		Serr("CCBI :: ");
		Serr.layout.convert(
			delegate uint(char[] s){ return Serr.write(s); },
			_arguments, _argptr, fmt);
	}

	version (statistics) void printStats(FormatOutput!(char) put) {
		put("============").newline;
		put(" Statistics ").newline;
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
		ss ~= Stat(null);
		ss ~= Stat("Pushed onto stack",             stackStats.pushes,             "cell");
		ss ~= Stat("Popped from stack",             stackStats.pops,               "cell");
		ss ~= Stat("Cleared from stack",            stackStats.cleared,            "cell");
		ss ~= Stat("Peeked stack",                  stackStats.peeks,              "time");
		ss ~= Stat("Cleared stack",                 stackStats.clears,             "time");
		ss ~= Stat("Underflowed stack during pop",  stackStats.popUnderflows,      "time");
		ss ~= Stat("Underflowed stack during peek", stackStats.peekUnderflows,     "time");
		ss ~= Stat("Resized stack",                 stackStats.resizes,            "time");
		ss ~= Stat(null);
		ss ~= Stat("Pushed onto deque",             dequeStats.pushes,             "cell");
		ss ~= Stat("Popped from deque",             dequeStats.pops,               "cell");
		ss ~= Stat("Cleared from deque",            dequeStats.cleared,            "cell");
		ss ~= Stat("Peeked deque",                  dequeStats.peeks,              "time");
		ss ~= Stat("Cleared deque",                 dequeStats.clears,             "time");
		ss ~= Stat("Underflowed deque during pop",  dequeStats.popUnderflows,      "time");
		ss ~= Stat("Underflowed deque during peek", dequeStats.peekUnderflows,     "time");
		ss ~= Stat("Resized deque",                 dequeStats.resizes,            "time");
		ss ~= Stat(null);
		ss ~= Stat("Pushed onto stack stack",       stackStackStats.pushes,        "container");
		ss ~= Stat("Popped from stack stack",       stackStackStats.pops,          "container");
		ss ~= Stat("Cleared from stack stack",      stackStackStats.cleared,       "container");
		ss ~= Stat("Peeked stack stack",            stackStackStats.peeks,         "time");
		ss ~= Stat("Cleared stack stack",           stackStackStats.clears,        "time");
		ss ~= Stat("Resized stack stack",           stackStackStats.resizes,       "time");
		ss ~= Stat(null);
		ss ~= Stat("Pushed onto semantic stack",    semanticStats.pushes,          "semantic");
		ss ~= Stat("Popped from semantic stack",    semanticStats.pops,            "semantic");
		ss ~= Stat("Cleared from semantic stack",   semanticStats.cleared,         "semantic");
		ss ~= Stat("Peeked semantic stack",         semanticStats.peeks,           "time");
		ss ~= Stat("Cleared semantic stack",        semanticStats.clears,          "time");
		ss ~= Stat("Resized semantic stack",        semanticStats.resizes,         "time");
		ss ~= Stat(null);
		ss ~= Stat("Forked",                        stats.ipForked,                "IP");
		ss ~= Stat("Stopped",                       stats.ipStopped,               "IP");
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

			if (stat.fin)
				put(' ')(stat.fin);
			put.newline;
		}
	}
}
