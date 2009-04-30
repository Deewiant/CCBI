// CCBI - Conforming Concurrent Befunge-98 Interpreter
// A Concurrent Befunge-98 interpreter.
// Copyright (c) 2006-2008 Matti Niemenmaa
// See license.txt for copyright details.

// See e.g. http://quadium.net/funge/spec98.html for the Funge-98 specification.

// File created: 2006-06-06

// The core functionality, main loop, etc.
module ccbi.ccbi;

import tango.core.Exception : ArgEx = IllegalArgumentException;
import tango.io.Stdout;
import tango.io.device.File : File;
import tango.text.Ascii     : toLower;

import ccbi.flags;
import ccbi.globals : VERSION_STRING;
import ccbi.fungemachine;
import ccbi.templateutils;
import ccbi.utils;

import ccbi.fingerprints.cats_eye.turt : TURT_FILE_INIT;

const char[]
	HELP = VERSION_STRING ~ `

 Copyright (c) 2006-2009 Matti Niemenmaa, http://www.iki.fi/matti.niemenmaa/
 See the file license.txt for copyright details.

Usage: {} ARGS SOURCE_FILE [FUNGE_ARGS...]

Interprets SOURCE_FILE as Funge-98 code, executing it and passing FUNGE_ARGS to
it as command line arguments. The default mode of operation is Befunge-98, but
this may be modified with the appropriate ARGS.

ARGS may be one or more of:
 -d1, --unefunge         Treat source as one-dimensional (Unefunge).
 -d2, --befunge          Treat source as two-dimensional (Befunge). This is the
                         default.
 -d3, --trefunge         Treat source as three-dimensional (Trefunge).

 -t, --trace             Trace source during interpretation.

 -w, --warnings          Warn when encountering unimplemented instructions.

 -s, --stats             Output some interesting statistics to stderr upon
                         completion.

     --script            Begin execution on the second line if the first line
                         begins with a shebang ("#!").

                         An infinite loop will occur if no second line exists,
                         or it is empty.

     --befunge-93        Adhere to the Befunge-93 documentation instead of the
                         Funge-98 specification.

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

The Mini-Funge library format accepted is that used by RC/Funge-98 version 1.16.

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

    "BASE"  0x42415345  I/O for numbers in other bases

      'N' and 'I' reverse unless 0 < base < 36.

    "CPLI"  0x43504c49  Complex Integer extension
    "DATE"  0x44415445  Date Functions
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

    "IIPC"  0x49495043  Inter IP [sic] communicaiton [sic] extension

      'A' reverses if the IP is the initial IP and thus has no ancestor.

    "IMAP"  0x494d4150  Instruction remap extension
    "INDV"  0x494e4456  Pointer functions
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

      Time travel to the past is implemented as rerunning from tick 0. Output
      (console/file) during rerunning is not performed. Console input results
      in constant values, which probably won't be the same as those that were
      originally input. The 'i' instruction is ignorant of TRDS, as are these
      fingerprints: DIRF, FILE, SOCK, SCKE.

    Intentionally unsupported fingerprints:
      Because they are not portable:
         "MSGQ"  0x4d534751
         "SGNL"  0x53474e4c
         "SMEM"  0x534d454d
         "SMPH"  0x534d5048

      "WIND" because I think the console is enough for anyone, especially
      anyone programming in Befunge.

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

	auto filePos = size_t.max;
	auto progName = args[0];
	args = args[1..$];

	Flags flags;
	byte dim = 2;
	bool befunge93 = false;

	// {{{ parse arguments
	argLoop: for (size_t i = 0; i < args.length; ++i) {

		bool help(char[] s) {
			switch (toLower(s.dup)) {
				case
					"-?", "--?", "/?", "-h", "--h", "/h",
					"-hlp", "--hlp", "/hlp", "-help", "--help", "/help":
						return true;
				default: return false;
			}
		}

		auto arg = args[i];

		char[] nextArg() {
			if (++i >= args.length)
				throw new ArgEx(
					Stderr.layout.convert(
						"Further argument required following {}.", arg));
			return args[i];
		}

		int msgOnly(char[] s) {
			Stderr(s).newline;
			return 0;
		}

		// TODO: switch to a proper argument parser
		with (flags) switch (arg) {
			case "-d1", "--unefunge":       dim = 1;                     break;
			case "-d2", "--befunge":        dim = 2;                     break;
			case "-d3", "--trefunge":       dim = 3;                     break;
			case "-t", "--trace":           tracing             = true;  break;
			case "-w", "--warnings":        warnings            = true;  break;
			case "-s", "--stats":           useStats            = true;  break;
			case       "--script":          script              = true;  break;
			case "-P", "--disable-fprints": fingerprintsEnabled = false; break;
			case       "--befunge-93":      befunge93           = true;  break;

/+			case "-m", "--mini-funge":
				auto s = nextArg();
				if (s == "0")
					miniMode = Mini.NONE;
				else if (s == "1")
					miniMode = Mini.ALL;
				else
					throw new ArgEx(Stderr.layout.convert(
						"Expected 0 or 1 following {}, not {}.", args[i-1], arg));
				break;
+/

/+			case "-d", "--draw-to":
				turtFile = nextArg();
				break;
+/

			case "-i", "--implementation": return msgOnly(IMPLEMENTATION);
			case "-p", "--print-fprints":  return msgOnly(FINGERPRINT_INFO);
			case "-v", "--version":        return msgOnly(VERSION_STRING);
			case "-f", "--file":
				nextArg();
				filePos = i;
				break;
			default:
				if (arg.help()) {
					Stderr.formatln(HELP, progName);
					return 1;
				} else {
					filePos = i;
					break argLoop;
				}
		}
	}

//	if (!fingerprintsEnabled && miniMode == Mini.ALL)
//		Stderr("Warning: --disable-fprints overrides --mini-funge 1").newline;

	if (filePos == size_t.max) {
		Stderr.formatln(HELP, args[0]);
		return 1;
	}

	auto fungeArgs = args[filePos..$];
	// }}}

	File file;
	try file = new typeof(file)(fungeArgs[0]);
	catch {
		Stderr("Couldn't open file '")(fungeArgs[0])("' for reading.").newline;
		return -1;
	}

	if (befunge93)
		return         (new FungeMachine!(2, true) (file, fungeArgs, flags)).run;
	else switch (dim) {
		case 1: return (new FungeMachine!(1, false)(file, fungeArgs, flags)).run;
		case 2: return (new FungeMachine!(2, false)(file, fungeArgs, flags)).run;
		case 3: return (new FungeMachine!(3, false)(file, fungeArgs, flags)).run;
		default: assert (false, "Internal error!");
	}
}
