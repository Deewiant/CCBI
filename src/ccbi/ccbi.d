// CCBI - Conforming Concurrent Befunge-98 Interpreter
// A Concurrent Befunge-98 interpreter.
// Copyright (c) 2006-2008 Matti Niemenmaa
// See license.txt for copyright details.

// See e.g. http://quadium.net/funge/spec98.html for the Funge-98 specification.

// File created: 2006-06-06

// The core functionality, main loop, etc.
module ccbi.ccbi;

import tango.core.Exception    : ArgEx = IllegalArgumentException;
import tango.io.device.Array   : Array;
import tango.io.device.File    : File;
import tango.io.device.FileMap : FileMap;
import tango.io.Stdout;
import tango.text.Arguments;
import tango.text.Ascii        : toLower;
import tango.text.Util         : delimiters;

import ccbi.fingerprints.all;
import ccbi.flags;
import ccbi.globals : VERSION_STRING;
import ccbi.fungemachine;
import ccbi.templateutils;
import ccbi.utils;

// Yay version combinations and --help strings
version (unefunge98)   version = funge98;
version ( befunge98) { version = funge98; version = notOnlyUne; }
version (trefunge98) { version = funge98; version = notOnlyUne; }

version (befunge93) version (funge98)
	version = funge93_and_98;

version (funge98) {} else version (befunge93) {} else
	static assert (false,
		"A Funge-98 standard or Befunge-93 must be versioned in.");

version (unefunge98) {
	version (notOnlyUne)
		const char[] UNEFUNGE_HELP = `
 -1, --unefunge          Treat source as one-dimensional (Unefunge-98).`;
	else
		const char[] UNEFUNGE_HELP = `
 -1, --unefunge          Treat source as one-dimensional (Unefunge-98). This is
                         the default.`;
} else
	const char[] UNEFUNGE_HELP = "";

version (befunge98)
	const char[] BEFUNGE_HELP = `
 -2, --befunge           Treat source as two-dimensional (Befunge-98). This is
                         the default.`;
else
	const char[] BEFUNGE_HELP = "";

version (trefunge98) {
	version (befunge98)
		const char[] TREFUNGE_HELP = `
 -3, --trefunge          Treat source as three-dimensional (Trefunge-98).`;
	else
		const char[] TREFUNGE_HELP = `
 -3, --trefunge          Treat source as three-dimensional (Trefunge-98). This
                         is the default.`;
} else
	const char[] TREFUNGE_HELP = "";

version (funge93_and_98) {
	const char[] BEFUNGE93_HELP = `

     --befunge-93        Adhere to the Befunge-93 documentation instead of the
                         Funge-98 specification.`;

	const char[] BEFUNGE93_OVERRIDE = `

                         Overrides --befunge-93.`;
} else {
	const char[] BEFUNGE93_HELP = "";
	const char[] BEFUNGE93_OVERRIDE = "";
}

version (statistics)
	const char[] STAT_HELP = `

 -s, --stats             Output some interesting statistics to stderr upon
                         completion.`;
else
	const char[] STAT_HELP = "";

version (tracer)
	const char[] TRACE_HELP = `

 -t, --trace             Enable the built-in tracer (debugger).`;
else
	const char[] TRACE_HELP = "";

version (funge98)
	const char[] FINGERPRINTS_HELP = `
 -f F, --fingerprints=F  Allow enabling and disabling of individual
                         fingerprints before starting the program. The
                         parameter F is a comma-separated list of fingerprint
                         names prefixed with '-' or '+'. Prefixing a name with
                         '-' disables it while '+' enables it. The special name
                         "all" can be used to modify the status of all
                         fingerprints at once.

                         By default, all fingerprints are enabled.`;
else
	const char[] FINGERPRINTS_HELP = "";

const char[]
	USAGE = `Usage: {} ARGS SOURCE_FILE [FUNGE_ARGS...]`,
	HELP = VERSION_STRING ~ `

 Copyright (c) 2006-2010 Matti Niemenmaa, http://www.iki.fi/matti.niemenmaa/
 See the file license.txt for copyright details.

` ~ USAGE ~ `

Interprets SOURCE_FILE as Funge-98 code, executing it and passing FUNGE_ARGS to
it as command line arguments. The default mode of operation is Befunge-98, but
this may be modified with the appropriate ARGS.

ARGS may be one or more of: `
	~ UNEFUNGE_HELP
	~ BEFUNGE_HELP
	~ TREFUNGE_HELP
	~ BEFUNGE93_HELP
	~ FINGERPRINTS_HELP
	~ TRACE_HELP
	~ STAT_HELP
	~ `

 -w, --warnings          Warn when encountering unimplemented instructions.

     --script            Begin execution on the second line if the first line
                         begins with a shebang ("#!").

                         An infinite loop will occur if no second line exists,
                         or it is empty.

 -i, --implementation    Show some implementation details and exit.

 -p, --print-fprints     List all supported (and intentionally unsupported)
                         fingerprints and their implementation notes, and exit.

 -h, --help              Show this help text and exit.
 -v, --version           Show the version string and exit.

 --                      Cease argument parsing: use the following argument as
                         SOURCE_FILE, and any later ones as BEFUNGE_ARGS.
                         Useful if you have a file named "--help", for
                         instance.`,
	IMPLEMENTATION =
`There is no Befunge-93 compatibility mode: update your programs to account for
the few corner cases where it actually matters.

The Mini-Funge library format accepted is that used by RC/Funge-98 version
1.16.

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
	Flags flags;

	version (befunge98)
		byte dim = 2;
	else version (trefunge98)
		byte dim = 3;
	else version (unefunge98)
		byte dim = 1;

	version (befunge93) {
		version (funge98)
			bool befunge93Mode = false;
		else
			bool befunge93Mode = true;
	}

	// {{{ parse arguments

	auto argp = new Arguments;
	bool failedParse = false;

	version (unefunge98) argp("unefunge").aliased('1').bind({ dim = 1; });
	version ( befunge98) argp( "befunge").aliased('2').bind({ dim = 2; });
	version (trefunge98) argp("trefunge").aliased('3').bind({ dim = 3; });

	version (befunge93)
		argp("befunge-93").bind({ befunge93Mode = true; });

	version (statistics)
		argp("stats")    .aliased('s').bind({ flags.useStats = true; });

	argp("trace")       .aliased('t').bind({ flags.tracing  = true; });
	argp("warnings")    .aliased('w').bind({ flags.warnings = true; });
	argp("script")                   .bind({ flags.script   = true; });

	version (funge98) {
		argp("fingerprints").aliased('f').params(1).smush.bind((char[] fs) {
			foreach (f; delimiters(fs, ",")) {
				bool enable = void;
				switch (f[0]) {
					case '-': enable = false; break;
					case '+': enable =  true; break;
					default:
						failedParse = true;
						Stderr("CCBI :: fingerprint setting '")(f)
								("' must be prefixed with - or +.").newline;
						return;
				}
				switch (f[1..$]) mixin (Switch!(
					FingerprintSettingCases!(ALL_FINGERPRINTS),
					`case "all":
						if (enable)
							flags.enabledFings.setAll();
						else
							flags.enabledFings.unsetAll();
						break;`,
					`default:
						if (enable) {
							failedParse = true;
							Stderr("CCBI :: cannot enable unknown fingerprint '")
						      	(f[1..$])("'.").newline;
						}
						break;`
				));
			}
		});
	}

	// TODO: minifunge, TURT file

	argp("implementation").aliased('i').halt.bind({ Stderr(  IMPLEMENTATION).newline; });
	argp("print-fprints") .aliased('p').halt.bind({ Stderr(FINGERPRINT_INFO).newline; });
	argp("version")       .aliased('v').halt.bind({ Stderr(  VERSION_STRING).newline; });

	argp("help").aliased('?').aliased('h').aliased('H')
		.halt.bind({ Stderr.formatln(HELP, args[0]); });

	argp( "hlp").halt.bind({ Stderr.formatln(HELP, args[0]); });
	argp("HELP").halt.bind({ Stderr.formatln(HELP, args[0]); });
	argp( "HLP").halt.bind({ Stderr.formatln(HELP, args[0]); });

	const char[][] ERRORS = [
		"CCBI :: argument '{0}' expects {2} parameter(s), but has only {1}.\n",
		"CCBI :: argument '{0}' expects {3} parameter(s), but has only {1}.\n",
		"CCBI :: argument '{0}' is missing.\n",
		"CCBI :: argument '{0}' must be used with '{4}'.\n",
		"CCBI :: argument '{0}' conflicts with '{4}'.\n",
		"CCBI :: unexpected argument '{0}'. Use '--help' for help.\n",
		"CCBI :: argument '{0}' expects one of {5}.\n",
	];

	if (!argp.parse(args[1..$]) || failedParse) {
		argp.errors(ERRORS);

		Stderr(argp.errors((char[] buf, char[] fmt, ...) {
			failedParse = true;
			return Stderr.layout.vprint(buf, fmt, _arguments, _argptr);
		}));
		return failedParse ? 1 : 0;
	}

	flags.allFingsDisabled = flags.enabledFings.allUnset;

	auto fungeArgs = argp("").assigned;
	if (!fungeArgs.length) {
		Stderr("CCBI :: missing source file.").newline.formatln(USAGE, args[0]);
		return 1;
	}
	// }}}

	auto filename = fungeArgs[0];

	Array file;
	try file = new FileMap(filename, File.ReadExisting);
	catch {
		try {
			scope intermediate = new File(filename);
			file = new Array(intermediate.load);
		} catch {
			Stderr("Couldn't open file '")(filename)("' for reading.").newline;
			return -1;
		}
	}

	version (befunge93)
		if (befunge93Mode)
			return         (new FungeMachine!(2,  true)(file, fungeArgs, flags)).run;

	switch (dim) {
		version (unefunge98) {
			case 1: return (new FungeMachine!(1, false)(file, fungeArgs, flags)).run;
		}
		version ( befunge98) {
			case 2: return (new FungeMachine!(2, false)(file, fungeArgs, flags)).run;
		}
		version (trefunge98) {
			case 3: return (new FungeMachine!(3, false)(file, fungeArgs, flags)).run;
		}
		default: assert (false, "Internal error!");
	}
}

template FingerprintSettingCases(fing...) {
	static if (fing.length)
		const FingerprintSettingCases =
			`case "` ~fing[0]~ `":
				flags.enabledFings.` ~PrefixName!(fing[0])~ ` = enable;
				break;`
			~ FingerprintSettingCases!(fing[1..$]);
	else
		const FingerprintSettingCases = "";
}
