// CCBI - Conforming Concurrent Befunge-98 Interpreter
// A Concurrent Befunge-98 interpreter.
// Copyright (c) 2006-2008 Matti Niemenmaa
// See license.txt for copyright details.

// See e.g. http://catseye.tc/projects/funge98/doc/funge98.html for the
// Funge-98 specification.

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

version (TURT)
	import ccbi.globals : turtFile, TURT_FILE_INIT;

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

version (funge93_and_98)
	const char[] BEFUNGE93_HELP = `

     --befunge93         Adhere to the Befunge-93 documentation instead of the
                         Funge-98 specification.`;
else
	const char[] BEFUNGE93_HELP = "";

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

version (detectInfiniteLoops)
	const char[] INFINITY_NOTE = "";
else
	const char[] INFINITY_NOTE = `

                         Note: not all infinite loop checks are enabled in this
                         build of CCBI.`;

version (funge98)
	const char[] SANDBOX_HELP = `

 -S, --sandbox           Sandbox mode: prevent the program from having any
                         lasting effect on the system. To be precise, disables
                         the o and = instructions and the following
                         fingerprints:`
	~ WordWrapFromTo(39, 26, Intercalate!(", ", SANDBOXED_FINGERPRINTS) ~ ".");
else
	const char[] SANDBOX_HELP = "";

version (TURT)
	const char[] TURT_HELP = `

    --turt-file=PATH     Use PATH as the file written to by the I instruction
                         in the TURT fingerprint. The default is `
                         ~TURT_FILE_INIT~ `.`;
else
	const char[] TURT_HELP = "";

version (funge98)
	const char[] IMPLEMENTATION_HELP = `

 -i, --implementation    Show some implementation details regarding the
                         Funge-98 specification and exit.

 -p, --print-fprints     List all supported fingerprints and their
                         implementation notes, and exit.`;
else
	const char[] IMPLEMENTATION_HELP = "";

const char[]
	USAGE = `Usage: {} ARGS SOURCE_FILE [FUNGE_ARGS...]`,
	HELP = VERSION_STRING ~ `

 Copyright (c) 2006-2010 Matti Niemenmaa, http://www.iki.fi/matti.niemenmaa/
 See the file license.txt for copyright details.

` ~ USAGE ~ `

Interprets SOURCE_FILE as Funge code, executing it and passing FUNGE_ARGS to it
as command line arguments.

ARGS may be one or more of: `
	~ UNEFUNGE_HELP
	~ BEFUNGE_HELP
	~ TREFUNGE_HELP
	~ BEFUNGE93_HELP
	~ FINGERPRINTS_HELP
	~ TRACE_HELP
	~ STAT_HELP
	~ `

 -d, --detect-infinity   Detect situations in which the program is irreversibly
                         stuck in an infinite loop, aborting with an error
                         message when that happens.`
	~ INFINITY_NOTE
	~ SANDBOX_HELP
	~ TURT_HELP
	~ `

 -w, --warnings          Warn when encountering unimplemented instructions.

     --script            Begin execution on the second line if the first line
                         begins with a shebang ("#!").

                         An infinite loop will occur if no second line exists,
                         or it is empty.`
	~ IMPLEMENTATION_HELP
	~ `

 -h, --help              Show this help text and exit.
 -v, --version           Show the version string and exit.

 --                      Cease argument parsing: use the following argument as
                         SOURCE_FILE, and any later ones as BEFUNGE_ARGS.
                         Useful if you have a file named "--help", for
                         instance.`,
	IMPLEMENTATION =
`Ambiguities or lack of information in the Funge-98 specification (henceforth
"spec") have been dealt with as follows.

Regarding instructions:
 'k' treats a negative argument as equivalent to a zero argument.

 '(' and ')' reflect given a negative cell count to pop.

 ',' flushes stdout when '\n' (ASCII 10) is passed to it. No other output
     instructions flush stdout.

 '&' and '~' flush stdout prior to reading stdin.

 '&', if receiving for instance "foo10bar", will push 10, but leave "bar" and
      the line break ('\r', '\n', or '\r\n') on the input buffer.

      The line break is taken off the input buffer if there is no trailing
      garbage after the number: for instance, if receiving only "foo10", the
      input buffer will be empty.

 '~'  converts '\r' and '\r\n' to '\n'. After '\r', another byte will thus be
      read to see if it is '\n'.

 '#', when moving out of bounds, skips over one of the large number of spaces
      which exist between the right edge of the code and the right edge of the
      address space. (Or, similarly, between the left edge of the space and the
      left edge of the code.) Thus, unless the # is at the very edge of space
      and the cell at the opposite edge is a nonspace, # over the edge is
      practically a no-op.

 'o', when treating the output as a linear text file, removes spaces before
      each EOL in the string to be output: that is, not only those found in the
      end of each row in the specified rectangle within Funge-Space. And
      similarly for EOLs before form feeds, in Trefunge.

      Also, line terminators ('\r', '\n', '\r\n') are converted to the line
      terminator used by the host system.

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

	FINGERPRINT_INFO =
		// After a long description we get two line breaks, but also before a new
		// header: we can't know from here whether the last fingerprint before a
		// new header has a long description, so just fix it up.
		Replace("\n\n\n", "\n\n",

		PrefixNonNull!("The following fingerprints are implemented:",
		Concat!(
			PrefixNonNull!(
				"\n\n Official Cat's Eye Technologies fingerprints:\n\n",
				ConcatMap!(FingerprintDescription, FINGERPRINTS_CATSEYE))[0..$-1],
			PrefixNonNull!(
				"\n\n RC/Funge-98 fingerprints:\n\n",
				ConcatMap!(FingerprintDescription, FINGERPRINTS_RCFUNGE98))[0..$-1],
			PrefixNonNull!(
				"\n\n Jesse van Herk's extensions to RC/Funge-98:\n\n",
				ConcatMap!(FingerprintDescription, FINGERPRINTS_JVH))[0..$-1],
			PrefixNonNull!(
				"\n\n GLFunge98 fingerprints:\n\n",
				ConcatMap!(FingerprintDescription, FINGERPRINTS_GLFUNGE98))[0..$-1]
		)));

int main(char[][] args) {
	Flags flags;

	version (befunge98)
		byte dim = 2;
	else version (trefunge98)
		byte dim = 3;
	else version (unefunge98)
		byte dim = 1;

	version (funge93_and_98) {
		bool befunge93Mode = false;
	}

	// {{{ parse arguments

	auto argp = new Arguments;
	bool failedParse = false;

	version (unefunge98) argp("unefunge").aliased('1').bind({ dim = 1; });
	version ( befunge98) argp( "befunge").aliased('2').bind({ dim = 2; });
	version (trefunge98) argp("trefunge").aliased('3').bind({ dim = 3; });

	version (funge93_and_98)
		argp("befunge93").bind({ befunge93Mode = true; });

	version (statistics)
		argp("stats")       .aliased('s').bind({ flags.useStats = true; });

	argp("trace")          .aliased('t').bind({ flags.tracing  = true; });
	argp("warnings")       .aliased('w').bind({ flags.warnings = true; });
	argp("script")                      .bind({ flags.script   = true; });
	argp("detect-infinity").aliased('d').bind({ flags.detectInfiniteLoops = true; });
	argp("sandbox")        .aliased('S').bind({ flags.sandboxMode = true; });

	version (TURT)
		argp("turt-file").params(1).bind((char[] s) { turtFile = s; });

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
				switch (f[1..$]) {
					mixin (FingerprintSettingCases!(ALL_FINGERPRINTS));
					case "all":
						if (enable)
							flags.enabledFings.setAll();
						else
							flags.enabledFings.unsetAll();
						break;
					default:
						if (enable) {
							failedParse = true;
							Stderr("CCBI :: cannot enable unknown fingerprint '")
						      	(f[1..$])("'.").newline;
						}
						break;
				}
			}
		});
	}

	version (funge98) {
		argp("implementation").aliased('i').halt.bind({ Stderr(  IMPLEMENTATION).newline; });
		argp("print-fprints") .aliased('p').halt.bind({ Stderr(FINGERPRINT_INFO).newline; });
	}
	argp("version")          .aliased('v').halt.bind({ Stderr(  VERSION_STRING).newline; });

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
		Stderr("CCBI :: missing source file. Use '--help' for help.").newline
		     .newline
		     .formatln(USAGE, args[0]);
		return 1;
	}

	if (fungeArgs.length > 2) {
		auto prev = fungeArgs[1];
		auto prevBlank = prev == "";

		foreach (arg; fungeArgs[2..$]) {
			auto blank = arg == "";
			if (prevBlank && blank) {
				Stderr("CCBI :: a Funge program cannot receive two consecutive empty arguments!").newline;
				return 1;
			}
			prev = arg;
			prevBlank = blank;
		}
	}
	// }}}

	auto filename = fungeArgs[0];

	Array file;
	try file = new FileMap(filename, File.ReadExisting);
	catch {
		try {
			scope intermediate = new File(filename, File.ReadExisting);
			file = new Array(intermediate.load);
		} catch {
			Stderr("Couldn't open file '")(filename)("' for reading.").newline;
			return -1;
		}
	}

	version (funge93_and_98) {
		if (befunge93Mode)
			return         (new FungeMachine!(2,  true)(file, fungeArgs, flags)).run;
	} else version (befunge93)
			return         (new FungeMachine!(2,  true)(file, fungeArgs, flags)).run;

	version (funge98) switch (dim) {
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
