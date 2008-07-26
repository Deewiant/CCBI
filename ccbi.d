// CCBI - Conforming Concurrent Befunge-98 Interpreter
// A Concurrent Befunge-98 interpreter.
// Copyright (c) 2006-2008 Matti Niemenmaa
// See license.txt for copyright details.

// See e.g. http://quadium.net/funge/spec98.html for the Funge-98 specification.

// File created: 2006-06-06

// The core functionality, main loop, etc.
module ccbi.ccbi;

import tango.core.Exception : ArgEx = IllegalArgumentException;
import tango.io.Buffer;
import tango.io.FileConduit;
import tango.io.Stdout;
import regex = tango.text.Regex;

import ccbi.instructions;
import ccbi.fingerprint;
import ccbi.ip;
import ccbi.space;
import ccbi.trace;
import ccbi.utils;

import ccbi.mini.vars : miniMode, Mini;

import ccbi.fingerprints.cats_eye.turt : turtFile = filename, TURT_FILE_INIT;

// remember to change ccbi.instructions.VERSION_NUMBER too!
const char[]
	VERSION_STRING =
		"CCBI - Conforming Concurrent Befunge-98 Interpreter version 1.0.11",
	HELP           = VERSION_STRING ~ `

 Copyright (c) 2006-2008 Matti Niemenmaa, http://www.iki.fi/matti.niemenmaa/
 See the file license.txt for copyright details.

Usage: {} ARGS SOURCE_FILE [BEFUNGE_ARGS...]

Interprets SOURCE_FILE as Befunge-98 code, executing it and passing
BEFUNGE_ARGS to it as command line arguments.

ARGS may be one or more of:
 -t, --trace             Trace source during interpretation.
 -c, --count-ticks       Output to stderr the number of Funge-98 ticks used in
                         execution, and the number of instructions executed.
                         Both are 64-bit unsigned integers and may overflow.
 -w, --warnings          Warn when encountering unimplemented instructions.
 -s, --script            Begin execution on the second line if the first line
                         begins with a shebang ("#!").
                         An infinite loop will occur if no second line exists,
                         or it is empty.
 -m, --mini-funge        If the following argument is 0, don't try to load a
                         Mini-Funge library if an unimplemented fingerprint is
                         requested by '('.
                         If it is 1, '(' will prefer Mini-Funge libraries over
                         the built-in semantics.
 -P, --disable-fprints   Run as if no fingerprints were implemented.
 -d, --draw-to           Use the following argument as the file name written to
                         in the I instruction of the TURT fingerprint. The
                         default is ` ~ TURT_FILE_INIT ~ `.
 -i, --implementation    Show some implementation details and exit.
 -p, --print-fprints     List all supported (and knowingly unsupported)
                         fingerprints and their implementation notes, and exit.
 -h, --help              Show this help text and exit.
 -v, --version           Show the version string and exit.
 -f, --file              Use the following argument as SOURCE_FILE, and any
                         later ones as BEFUNGE_ARGS.
                         Useful if you have a file named "--help", for
                         instance.`,
	IMPLEMENTATION =
`There is no Befunge-93 compatibility mode: update your programs to account for
the few corner cases where it actually matters.

The Mini-Funge library format accepted is that used by RC/Funge-98.

Ambiguities or lack of information in the Funge-98 specification (henceforth
"spec") have been dealt with as follows.

Regarding instructions:
 'k' with a negative argument does nothing.

 '(' and ')' with a negative cell count to pop treat it as a zero, thus
             reversing since there is no fingerprint equal to zero.

 ',' flushes stdout when '\n' (ASCII 10) is passed to it. No other output
     instructions flush stdout.

 '&' and '~' flush stdout prior to reading stdin.

 '&', if receiving for instance "foo10bar", will push 10, but leave "bar" and
      the line break ('\r', '\n', or '\r\n') on the input buffer.

      The line break is taken off the input buffer if there is no trailing
      garbage after the number: for instance, if receiving only "foo10", the
      input buffer will be empty.

 '~'  converts '\r' and '\r\n' to '\n'.

 '#', when moving out of bounds, skips over the edgemost cell in the file.

      However, since space is treated as a rectangle, if the line (to simplify,
      consider only this case where the delta is (1,0) or (-1,0)) on which the
      # occurs is not the longest line in the file, the IP will find a cell
      containing a space and jump over that, thus hitting the edgemost
      instruction placed on the line. For instance:

      >]#
      #]

      The jump on the first line will skip over the '>' and hit the ']', but
      the jump on the second line will skip over a space, not the ']'.

      I have seen at least three different ways of handling this in existing
      interpreters, and since the specification isn't clear on this, I have no
      intention of correcting this behaviour to be more consistent, as this is
      the easiest way of programming it and results in the fastest code. If a
      standard, even a de facto standard, is established, I'll gladly conform
      to it, but such a thing doesn't exist (yet).

 'o', when treating the output as a linear text file, removes spaces before
      each EOL in the string to be output: that is, not only those found in the
      end of each row in the specified rectangle within Funge-space.

      Also, '\n' and '\r' characters (ASCII 10 and 13) are converted to the
      line separator used by the host system.

 't' not only reflects the resulting IP but also moves it once prior to its
     first execution, to prevent every 't' instruction from being a forkbomb.

     There is no particular limit to the number of IPs allowed, but as the
     ID is a 32-bit signed integer, if there are 2^32 or more concurrent IPs,
     not all will have unique IDs.

 'y' always pushes a "team number" of zero, as the concept is completely
     undocumented apart from this one mention.

Other notes:
 Stringmode is not global, it is per-IP. This would make sense and is evidently
 expected by string-using Concurrent Funge-98 programs, but is not in the spec.

 Wherever the Concurrent Funge-98 spec mentions the stack, it has been taken as
 referring to the stack stack.`,

	FINGERPRINT_INFO = `The following fingerprints are implemented:

  Official Cat's Eye Technologies fingerprints:

    "HRTI"  0x48525449  High-Resolution Timer Interface
    "MODE"  0x4d4f4445  Funge-98 Standard Modes

      The stack stack is unaffected by both invertmode and queuemode.

    "MODU"  0x4d4f4455  Modulo Arithmetic Extension

      All instructions ('M', 'U', 'R') push a zero when division by zero would
      occur, to match the behaviour of '%'.

    "NULL"  0x4e554c4c  Funge-98 Null Fingerprint
    "ORTH"  0x4f525448  Orthogonal Easement Library

      'G' and 'P' do not apply the storage offset.

    "PERL"  0x5045524c  Generic Interface to the Perl Language

      The result of 'E' and 'I' which is pushed is what eval() returned.

      Anything that the Perl program writes to stdout or stderr is passed on to
      CCBI's stdout. Trying to forcibly write to stderr from within the Perl
      (through tricks such as 'open($my_stderr, ">&2")') is deemed undefined
      behaviour and you do so at your own risk.

    "REFC"  0x52454643  Referenced Cells Extension

      Since there is no way of removing a vector from the list, prolific use of
      'R' can and will lead to a shortage of memory.

    "ROMA"  0x524f4d41  Funge-98 Roman Numerals
    "TOYS"  0x544f5953  Funge-98 Standard Toys

      'B' pops y, then x, and pushes x+y, then x-y. This may or may not be the
          the "butterfly bit operation" requested.

      'H' performs a signed right shift.

      'T' reverses if the dimension number is too big or small (not 0 or 1).

      'Z' reverses since this isn't Trefunge.

    "TURT"  0x54555254  Simple Turtle Graphics Library

      'I' creates an SVG 1.1 file.

  RC/Funge-98 fingerprints:

    Precise semantics have been read from the RC/Funge-98 source where not
    properly documented. Any changes and important undocumented features
    (though I would call some bugs) are noted here.

    For all fingerprints involving vectors, RC/Funge-98 doesn't, for some
    reason, use the IP's storage offset. Thus, neither does CCBI.

    "BASE"  0x42415345  I/O for numbers in other bases

      'N' and 'I' reverse unless 0 < base < 36.

    "CPLI"  0x43504c49  Complex Integer extension
    "DIRF"  0x44495246  Directory functions extension
    "EVAR"  0x45564152  Environment variables extension

      'P' reverses if the string it pops is not of the form name=value.

    "FILE"  0x46494c45  File I/O functions
    "FIXP"  0x46495850  Some useful math functions

      'B', 'C', 'I', 'J', 'P', 'Q', 'T', and 'U' round the number using the
                                                 current rounding mode.

    "FPDP"  0x46504450  Double precision floating point
    "FPSP"  0x46505350  Single precision floating point

      The following notes apply to both of the above:

      'F' rounds the number using the current rounding mode.

      'P' prints like the standard '.', with a space after the number.

      'R' reverses if the string doesn't represent a floating point number.

    "FRTH"  0x46525448  Some common forth [sic] commands

      'D' will push a negative number if the stack size is greater than or
          equal to 2^31 - 1, the maximum size of a 32-bit Funge-Space cell.

      'L' and 'P' both push a zero if the argument they pop is greater than or
                  equal to the size of the stack after the pop.

      All commands push on top of the stack regardless of whether invert mode
      (from the MODE fingeprint) is on, since the FORTH ANSI standard speaks
      not of pushing, but only of the top of the stack, which is unaffected by
      invert mode.

    "IIPC"  0x49495043  Inter IP [sic] communicaiton [sic] extension

      'A' reverses if the IP is the initial IP and thus has no ancestor.

    "IMAP"  0x494d4150  Instruction remap extension

      The remapping is per-IP, and works only for ASCII values (0-127).

      "Chains" of mappings aren't allowed: if you map A to B and B to C, A will
      do what B normally does, and B will do what C normally does. A _won't_ do
      what C normally does.

    "INDV"  0x494e4456  Pointer functions
    "PNTR"  0x504e5452  (an alias of "INDV")

      Like RC/Funge-98, 'V' and 'W' push and pop the vector in different orders,
      so that a vector put with 'W' and subsequently got with 'V' will have its
      components reversed.

    "SOCK"  0x534f434b  tcp/ip [sic] socket extension

      'A' will push zeroes for both the port and address if the address is not
          IPv4 (AF_INET/PF_INET).

    "STRN"  0x5354524e  String functions

      'G' will reverse if it detects it is in an infinite loop, looking for a
          terminating zero outside the Funge-Space boundaries.

    "SUBR"  0x53554252  Subroutine extension
    "TERM"  0x5445524d  Terminal control functions

      Each instruction reverses on error under Windows.

      TERM isn't implemented on Posix, unfortunately. If you think you can
      help with that, please do.

    "TIME"  0x54494d45  Time and Date functions
    "TRDS"  0x54524453  IP travel in time and space

      'G' pushes a 32-bit truncation of the 64-bit counter.

    The "FNGR" fingerprint is unimplemented because it is incompatible with the
    way fingerprint loading and unloading is described in the Funge-98
    specification.

    In particular, the Funge-98 spec speaks of having a stack of semantics for
    each instruction in the range ['A', 'Z'], while the "FNGR" fingerprint
    describes having just one fingerprint stack.

    (Incidentally, this is one reason why RC/Funge-98 fails some of the Mycology
    tests related to the fingerprint mechanism.)

    "SGNL" is unsupported because it is platform-specific.

    "WIND" is unsupported because I think the console is enough for anyone,
    especially anyone programming in Befunge.

  Jesse van Herk's extensions to RC/Funge-98:

    "JSTR"  0x4a535452
    "NCRS"  0x4e435253  Ncurses [sic] extension

  GLFunge98 fingerprints:

    "SCKE"  0x53434b45`;

int main(char[][] args) {
	if (args.length < 2) {
		Stderr.formatln(HELP, args[0]);
		return 1;
	}

	bool countTicks, script;
	auto filePos = size_t.max;

	args = args[1..$];

	scope helpRegex = regex.Regex("^(?--?|/)(?[?]|h(?e?lp)?)$", "i");
	argLoop: for (size_t i = 0; i < args.length; ++i) {

		bool help(char[] s) { return helpRegex.test(s); }

		auto arg = args[i];

		char[] nextArg() {
			if (++i >= args.length)
				throw new ArgEx(Stderr.layout.convert("Further argument required following {}.", arg));
			return args[i];
		}

		switch (arg) {
			case "-t", "--trace":           trace               = true;  break;
			case "-c", "--count-ticks":     countTicks          = true;  break;
			case "-w", "--warnings":        warnings            = true;  break;
			case "-s", "--script":          script              = true;  break;
			case "-P", "--disable-fprints": fingerprintsEnabled = false; break;

			case "-m", "--mini-funge":
				auto s = nextArg();
				if (s == "0")
					miniMode = Mini.NONE;
				else if (s == "1")
					miniMode = Mini.ALL;
				else
					throw new ArgEx(Stderr.layout.convert("Expected 0 or 1 following {}, not {}.", args[i-1], arg));
				break;

			case "-d", "--draw-to":
				turtFile = nextArg();
				break;

			case "-i", "--implementation": Stderr(IMPLEMENTATION  ).newline; return 1;
			case "-p", "--print-fprints":  Stderr(FINGERPRINT_INFO).newline; return 1;
			case "-v", "--version":        Stderr(VERSION_STRING  ).newline; return 1;
			case "-f", "--file":
				nextArg();
				filePos = i;
				break;
			default:
				if (arg.help()) {
					Stderr.formatln(HELP, args[0]);
					return 1;
				} else {
					filePos = i;
					break argLoop;
				}
		}
	}

	if (!fingerprintsEnabled && miniMode == Mini.ALL)
		Stderr("Warning: --disable-fprints overrides --mini-funge 1").newline;

	if (filePos == size_t.max) {
		Stderr.formatln(HELP, args[0]);
		return 1;
	}

	fungeArgs = args[filePos..$];

	FileConduit file;
	try file = new typeof(file)(fungeArgs[0]);
	catch {
		Stderr("Couldn't open file '")(fungeArgs[0])("' for reading.").newline;
		return -1;
	}

	Stdout.stream(new Buffer(new RawCoutFilter!(false), 32 * 1024));
	Stderr.stream(new Buffer(new RawCoutFilter!(true ), 32 * 1024));

	Out = new typeof(Out)(Stdout.stream);

	//
	// START BEFUNGE
	//

	// needs to be reloaded for TRDS
	typeof(space) initialSpace;

	loadIntoFungeSpace!(true)(&initialSpace, file, &initialSpace.endX, &initialSpace.endY);

	initialSpace.lastGet = initialSpace[0,0];

	void boot() {
		if (fingerprintsEnabled)
			space = initialSpace.copy;
		else
			space = initialSpace;

		ips[0] = IP();
		if (script && space[0,0] == '#' && space[1,0] == '!')
			ips[0].y = 1;
	}

	ips.length = 1;
	boot();
	ccbi.trace.tip = &ips[0];

	// for TRDS, jumping backwards in time
	typeof(ip.jumpedTo) latestJumpTarget;

	try execution: for (;;) {
		// TRDS: have to do all kinds of crap if time is stopped
		static bool normalTime = void;

		if (fingerprintsEnabled) {
			normalTime = (IP.timeStopper == IP.TIMESTOPPER_INIT);

			if (normalTime) {
				++ticks;

				// just jump into the future if nobody's doing anything in the meanwhile
				if (ip && ip.jumpedTo > ticks && ips.length == 1)
					ticks = ip.jumpedTo;

				for (size_t i = 0; i < travelers.length; ++i) {

					// self-explanatory: if the traveler is coming here, put it here
					if (ticks == travelers[i].jumpedTo)
						ips ~= travelers[i];

					/+

					More complicated, best explained with an example, and I'm still not sure I
					understand it fully.

					TRDS is a wonderful source of confusion. It helps that RC/Funge-98, in which it
					originated, doesn't implement it properly.

					See ccbi.fingerprints.rcfunge98.trds.jump for a longer comment which explains
					other stuff.

					- IP 1 travels from time 300 to 200.
					- We rerun from time 0 to 200, then place the IP. It does some stuff,
					  then teleports and jumps back to 300.
					- IP 2 travels from time 400 to 100
					- We rerun from time 0 to 100, then place the IP. It does some stuff,
					  then teleports and jumps back to 400.
					- At time 300, IP 1 travels again to 200.
					- We rerun from time 0 to 200. But at time 100, we need to place IP 2
					  again. So we do. (Hence the whole travelers array.)
					- It does its stuff, and teleports and freezes itself until 400.
					- Come time 200, we would place IP 1 again if we hadn't done the
					  following, and removed it back when we placed IP 2 for the second
					  time.
					+/

					else if (latestJumpTarget < travelers[i].jumpedTo)
						travelers = travelers[0..i] ~ travelers[i+1..$];
				}
			}
		} else
			++ticks;

		static bool executable(IP i) {
			// IIPC: don't execute if dormant
			// TRDS: if time is stopped, execute only for the time stopper
			//       and if the IP is jumping to the future, don't execute
			return (
				!fingerprintsEnabled || (
					!(i.mode & IP.DORMANT) &&
					(normalTime || IP.timeStopper == i.id) &&
					ticks >= i.jumpedTo
				)
			);
		}

		// eat spaces and semicolons for all IPs before tracing and execution
		// the easiest way to handle concurrent tracing and zero tick instructions
		if (fingerprintsEnabled) {
			foreach (inout i; ips)
			if (executable(i))
				i.gotoNextInstruction();
		} else
			foreach (inout i; ips)
				i.gotoNextInstruction();

		// note that if an IP modifies the space where another IP is with an instruction like p,
		// and does it in the same tick but before this other IP executes,
		// that one might run into a space or a semicolon which isn't caught by the above
		// hence we still need the functions for ' ' and ';' in instructions
		// and tracing can't catch this since you can't trace an IP at a time, only a tick at a time

		bool tracing = trace;

		// parent IP is executed last
		for (auto j = ips.length; j--;)
		if (executable(ips[j])) {
			.ip = &ips[j];

			auto i = space[ip.x, ip.y];

			if (tracing) {
				// trace only once per tick
				tracing = false;
				if (!doTrace()) {
					assert (stateChange);
					goto changeState;
				}
			}

			execute(i);

			changeState: switch (stateChange) {
				default: assert (false);

				case State.UNCHANGING: break;

				case State.STOPPING:
					if (ips.length == 1)
						goto case State.QUITTING;

					if (tip is ip)
						tip = null;

					if (fingerprintsEnabled) {
						// TRDS: resume time if the time stopper dies
						if (!normalTime)
							IP.timeStopper = IP.TIMESTOPPER_INIT;

						// TRDS: store data of stopped IPs which have jumped
						// see ccbi.fingerprints.rcfunge98.trds.jump() for the reason
						if (ip.jumpedAt) {
							bool found = false;

							foreach (dat; stoppedIPdata)
							if (dat.id == ip.id && dat.jumpedAt == ip.jumpedAt) {
								found = true;
								break;
							}

							if (!found)
								stoppedIPdata ~= StoppedIPData(ip.id, ip.jumpedAt, ip.jumpedTo);
						}
					}

					tipSafe({ips = ips[0..j] ~ ips[j+1..$];});

					stateChange = State.UNCHANGING;
					continue;

				case State.QUITTING:
					break execution;

				case State.TIMEJUMP:

					stateChange = State.UNCHANGING;

					// nothing special if jumping to the future, just don't trace it
					if (ticks != 0) {
						if (ip.jumpedTo >= ip.jumpedAt)
							ip.mode &= ~IP.FROM_FUTURE;

						if (ip is tip)
							tip = null;
						break;
					}

					// add ip to the list of travelers unless it's already there
					bool found = false;

					foreach (traveler; travelers)
					if (traveler.id == ip.id && traveler.jumpedAt == ip.jumpedAt) {
						found = true;
						break;
					}

					if (!found) {
						ip.mode |= IP.FROM_FUTURE;
						travelers ~= ip.copy;
					}

					latestJumpTarget = ip.jumpedTo;
					boot();

					continue execution;
			}

			if (needMove) {
				// see comment in ccbi.trace.findTip() for why ips[j] instead of ip
				ips[j].move();
			} else
				needMove = true;
		}

	} catch (Exception e) {
		Stdout.flush;
		Stderr("Exited due to an error: ")(e.msg)(" at ")(e.file)(':')(e.line).newline;
	}
	
	if (countTicks) {
		Stdout.flush;
		Stderr(executionCount)(" instructions executed in ")(ticks)(" ticks elapsed.").newline;
	}

	return returnVal;
}

ulong executionCount = 0;

void execute(cell i) {
	++executionCount;

	if (ip.mode & IP.STRING) {
		if (i == '"')
			ip.mode ^= IP.STRING;
		else
			ip.stack.push(i);
	} else {
		if (fingerprintsEnabled) {
			// IMAP fingerprint
			if (i >= 0 && i < ip.mapping.length) {
				i = ip.mapping[i];

				if (isSemantics(i))
					return executeSemantics(i in ip.semantics);
			}
		}

		executeInstruction(i);
	}
}
