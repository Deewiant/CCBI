// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2008-09-05 15:29:14

module ccbi.fingerprints.all;

import tango.core.Tuple;

import ccbi.cell;
import ccbi.templateutils;

version  (HRTI) public import ccbi.fingerprints.cats_eye .hrti;
version  (MODE) public import ccbi.fingerprints.cats_eye .mode;
version  (MODU) public import ccbi.fingerprints.cats_eye .modu;
version  (NULL) public import ccbi.fingerprints.cats_eye .null_;
version  (ORTH) public import ccbi.fingerprints.cats_eye .orth;
version  (PERL) public import ccbi.fingerprints.cats_eye .perl;
version  (REFC) public import ccbi.fingerprints.cats_eye .refc;
version  (ROMA) public import ccbi.fingerprints.cats_eye .roma;
version  (TOYS) public import ccbi.fingerprints.cats_eye .toys;
version  (TURT) public import ccbi.fingerprints.cats_eye .turt;
version  (SCKE) public import ccbi.fingerprints.glfunge98.scke;
version  (JSTR) public import ccbi.fingerprints.jvh      .jstr;
version  (NCRS) public import ccbi.fingerprints.jvh      .ncrs;
version (_3DSP) public import ccbi.fingerprints.rcfunge98._3dsp;
version  (BASE) public import ccbi.fingerprints.rcfunge98.base;
version  (CPLI) public import ccbi.fingerprints.rcfunge98.cpli;
version  (DATE) public import ccbi.fingerprints.rcfunge98.date;
version  (DIRF) public import ccbi.fingerprints.rcfunge98.dirf;
version  (EVAR) public import ccbi.fingerprints.rcfunge98.evar;
version  (FILE) public import ccbi.fingerprints.rcfunge98.file;
version  (FING) public import ccbi.fingerprints.rcfunge98.fing;
version  (FIXP) public import ccbi.fingerprints.rcfunge98.fixp;
version  (FPDP) public import ccbi.fingerprints.rcfunge98.fpdp;
version  (FPSP) public import ccbi.fingerprints.rcfunge98.fpsp;
version  (FRTH) public import ccbi.fingerprints.rcfunge98.frth;
version  (IIPC) public import ccbi.fingerprints.rcfunge98.iipc;
version  (IMAP) public import ccbi.fingerprints.rcfunge98.imap;
version  (INDV) public import ccbi.fingerprints.rcfunge98.indv;
version  (REXP) public import ccbi.fingerprints.rcfunge98.rexp;
version  (SOCK) public import ccbi.fingerprints.rcfunge98.sock;
version  (STRN) public import ccbi.fingerprints.rcfunge98.strn;
version  (SUBR) public import ccbi.fingerprints.rcfunge98.subr;
version  (TERM) public import ccbi.fingerprints.rcfunge98.term;
version  (TIME) public import ccbi.fingerprints.rcfunge98.time;
version  (TRDS) public import ccbi.fingerprints.rcfunge98.trds;

alias Tuple!(
	// Cat's Eye
	"PERL", "TURT",

	// RC/Funge-98
	"DIRF", "FILE", "SOCK",

	// GLfunge98
	"SCKE"
) SANDBOXED_FINGERPRINTS;

private char[] CatsEyeFingerprints() {
	char[] s = "alias Tuple!(";
	version  (HRTI) s ~= `"HRTI",`;
	version  (MODE) s ~= `"MODE",`;
	version  (MODU) s ~= `"MODU",`;
	version  (NULL) s ~= `"NULL",`;
	version  (ORTH) s ~= `"ORTH",`;
	version  (PERL) s ~= `"PERL",`;
	version  (REFC) s ~= `"REFC",`;
	version  (ROMA) s ~= `"ROMA",`;
	version  (TOYS) s ~= `"TOYS",`;
	version  (TURT) s ~= `"TURT",`;
	if (s[$-1] == ',')
		s = s[0..$-1];
	return s ~ ") FINGERPRINTS_CATSEYE;";
}
mixin (CatsEyeFingerprints());
private char[] JesseVanHerkFingerprints() {
	char[] s = "alias Tuple!(";
	version  (JSTR) s ~= `"JSTR",`;
	version  (NCRS) s ~= `"NCRS",`;
	if (s[$-1] == ',')
		s = s[0..$-1];
	return s ~ ") FINGERPRINTS_JVH;";
}
mixin (JesseVanHerkFingerprints());
private char[] RCFunge98Fingerprints() {
	char[] s = "alias Tuple!(";
	version (_3DSP) s ~= `"3DSP",`;
	version  (BASE) s ~= `"BASE",`;
	version  (CPLI) s ~= `"CPLI",`;
	version  (DATE) s ~= `"DATE",`;
	version  (DIRF) s ~= `"DIRF",`;
	version  (EVAR) s ~= `"EVAR",`;
	version  (FILE) s ~= `"FILE",`;
	version  (FING) s ~= `"FING",`;
	version  (FIXP) s ~= `"FIXP",`;
	version  (FPDP) s ~= `"FPDP",`;
	version  (FPSP) s ~= `"FPSP",`;
	version  (FRTH) s ~= `"FRTH",`;
	version  (IIPC) s ~= `"IIPC",`;
	version  (IMAP) s ~= `"IMAP",`;
	version  (INDV) s ~= `"INDV",`;
	version  (REXP) s ~= `"REXP",`;
	version  (SOCK) s ~= `"SOCK",`;
	version  (STRN) s ~= `"STRN",`;
	version  (SUBR) s ~= `"SUBR",`;
	version  (TERM) s ~= `"TERM",`;
	version  (TIME) s ~= `"TIME",`;
	version  (TRDS) s ~= `"TRDS",`;
	if (s[$-1] == ',')
		s = s[0..$-1];
	return s ~ ") FINGERPRINTS_RCFUNGE98;";
}
mixin (RCFunge98Fingerprints());
private char[] GLFunge98Fingerprints() {
	char[] s = "alias Tuple!(";
	version (SCKE) s ~= `"SCKE",`;
	if (s[$-1] == ',')
		s = s[0..$-1];
	return s ~ ") FINGERPRINTS_GLFUNGE98;";
}
mixin (GLFunge98Fingerprints());

alias Tuple!(
	FINGERPRINTS_CATSEYE,
	FINGERPRINTS_JVH,
	FINGERPRINTS_RCFUNGE98,
	// SCKE (GLFunge98) uses stuff from SOCK (RCFunge98): must be after it here
	FINGERPRINTS_GLFUNGE98) ALL_FINGERPRINTS;

alias Map!(PrefixName, ALL_FINGERPRINTS) ALL_FINGERPRINT_IDS;

template FingerprintDescription(char[] fing) {
	const FingerprintDescription =
		"   " ~ fing ~ "  0x" ~ ToHexString!(HexCode!(fing))
		             ~ "  " ~ mixin (PrefixName!(fing) ~ "Desc!()")
		             ~ \n;
}

// case HexCode!("<fingerprint>"):
// 	static if (TupleHas!("<fingerprint>", SANDBOXED_FINGERPRINTS))
// 		if (flags.sandboxMode)
// 			return null;
// 	if (!flags.enabledFings.<fingerprint>)
// 		return null;
// 	return <fingerprint>Instructions!();
template FingerprintInstructionsCase(char[] fing) {
	const FingerprintInstructionsCase =
		`case `~ToString!(HexCode!(fing))~`:`

			~ (TupleHas!(fing, SANDBOXED_FINGERPRINTS)
				? "if (flags.sandboxMode) return null;"
				: "") ~

			`if (!flags.enabledFings.`~PrefixName!(fing)~`)`
				`return null;`
			`return `~PrefixName!(fing)~`Instructions!();`;
}

// Each fingerprint may have a constructor and a destructor. We keep track of
// how many instructions of that fingerprint are loaded. If the count is at
// zero when the fingerprint is loaded, we call the constructor. Likewise, if
// the number of instructions drops back to zero the destructor is called.
//
// The count is local to the FungeMachine: there are (at least currently) no
// static fingerprint constructors/destructors.

// _<fingerprint>_count if the fingerprint has a constructor
//
// Leading underscore because we have names like 3DSP; could use PrefixName,
// but simpler to just always prefix.
template FingerprintCount(char[] fing) {
	const FingerprintCount =
		"static if (is(typeof(" ~PrefixName!(fing)~ ".ctor))) {
			uint _" ~fing~ "_count = 0;
		}";
}

// static if (is(typeof(<fingerprint>.ctor)) ||
//            is(typeof(<fingerprint>.ipCtor)))
// {
// 	case HexCode!("<fingerprint>"):
// }
// static if (is(typeof(<fingerprint>.ctor))) {
// 		if (_<fingerprint>_count == 0)
// 			<fingerprint>.ctor;
// 		_<fingerprint>_count += <fingerprint>Instructions!().length;
// }
// static if (is(typeof(<fingerprint>.ipCtor))) {
// 		if (cip._<fingerprint>_count == 0)
// 			<fingerprint>.ipCtor;
// 		cip._<fingerprint>_count += <fingerprint>Instructions!().length;
// }
// static if (is(typeof(<fingerprint>.ctor)) ||
//            is(typeof(<fingerprint>.ipCtor)))
// {
// 		break;
// }
template FingerprintConstructorCase(char[] fing) {
	const FingerprintConstructorCase =
		"static if (is(typeof(" ~PrefixName!(fing)~ ".ctor)) ||
			         is(typeof(" ~PrefixName!(fing)~ ".ipCtor))) {
			case " ~ToString!(HexCode!(fing)) ~":
		}
		static if (is(typeof(" ~PrefixName!(fing)~ ".ctor))) {
				if (_" ~fing~"_count == 0)
					" ~PrefixName!(fing)~ ".ctor;

				_" ~fing~"_count += " ~PrefixName!(fing)~ "Instructions!().length;
		}
		static if (is(typeof(" ~PrefixName!(fing)~ ".ipCtor))) {
				if (cip._" ~fing~"_count == 0)
					" ~PrefixName!(fing)~ ".ipCtor;

				cip._" ~fing~"_count += "~
					PrefixName!(fing)~"Instructions!().length;
		}
		static if (is(typeof(" ~PrefixName!(fing)~ ".ctor)) ||
			        is(typeof(" ~PrefixName!(fing)~ ".ipCtor))) {
				break;
		}";
}

// static if (is(typeof(<fingerprint>.ctor)) ||
//            is(typeof(<fingerprint>.ipCtor)))
// {
// 	case HexCode!("<fingerprint>"):
// }
// static if (is(typeof(<fingerprint>.ctor))) {
// 		--_<fingerprint>_count;
//
// 		static if (is(typeof(<fingerprint>.dtor)))
// 			if (_<fingerprint>_count == 0)
// 				<fingerprint>.dtor;
// }
// static if (is(typeof(<fingerprint>.ipCtor))) {
// 		--cip._<fingerprint>_count;
//
// 		static if (is(typeof(<fingerprint>.ipDtor)))
// 			if (cip._<fingerprint>_count == 0)
// 				<fingerprint>.ipDtor;
// }
// static if (is(typeof(<fingerprint>.ctor)) ||
//            is(typeof(<fingerprint>.ipCtor)))
// {
// 		break;
// }
template FingerprintDestructorCase(char[] fing) {
	const FingerprintDestructorCase =
		"static if (is(typeof(" ~PrefixName!(fing)~ ".ctor)) ||
			         is(typeof(" ~PrefixName!(fing)~ ".ipCtor)))
		{
			case " ~ToString!(HexCode!(fing)) ~":
		}
		static if (is(typeof(" ~PrefixName!(fing)~ ".ctor))) {
				--_" ~fing~"_count;

				static if (is(typeof(" ~PrefixName!(fing)~ ".dtor)))
					if (_" ~fing~"_count == 0)
						" ~PrefixName!(fing)~ ".dtor;
		}
		static if (is(typeof(" ~PrefixName!(fing)~ ".ipCtor))) {
				--cip._" ~fing~"_count;

				static if (is(typeof(" ~PrefixName!(fing)~ ".ipDtor)))
					if (cip._" ~fing~"_count == 0)
						" ~PrefixName!(fing)~ ".ipDtor;
		}
		static if (is(typeof(" ~PrefixName!(fing)~ ".ctor)) ||
			        is(typeof(" ~PrefixName!(fing)~ ".ipCtor)))
		{
				break;
		}";
}

// foreach fingerprint:
// 	case HexCode!("<fingerprint>"):
// 		switch (ins) {
// 			mixin (Ins!("<fingerprint>", Range!('A', 'Z')));
// 			default: def
// 		}
//       break;
template FingerprintExecutionCases(char[] ins, char[] def, fing...) {
	static if (fing.length)
		const FingerprintExecutionCases =
			`case `~ToString!(HexCode!(fing[0]))~`: `
				`switch (`~ins~`) {`
				`	mixin (Ins!(`~Wrap!(PrefixName!(fing[0]))~`, Range!('A','Z')));`
					`default: `~ def ~
				`}`
				`break;`
			~ FingerprintExecutionCases!(ins, def, fing[1..$]);
	else
		const FingerprintExecutionCases = "";
}
