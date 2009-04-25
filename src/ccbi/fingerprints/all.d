// File created: 2008-09-05 15:29:14

module ccbi.fingerprints.all;

import tango.core.Tuple;

import ccbi.cell;
import ccbi.templateutils;
public import
	ccbi.fingerprints.cats_eye.hrti,
	ccbi.fingerprints.cats_eye.mode,
	ccbi.fingerprints.cats_eye.modu,
	ccbi.fingerprints.cats_eye.null_,
	ccbi.fingerprints.cats_eye.orth,
	ccbi.fingerprints.cats_eye.perl,
	ccbi.fingerprints.cats_eye.refc,
	ccbi.fingerprints.cats_eye.roma,
	ccbi.fingerprints.cats_eye.toys,
	ccbi.fingerprints.cats_eye.turt,
	ccbi.fingerprints.glfunge98.scke,
	ccbi.fingerprints.jvh.jstr,
	ccbi.fingerprints.jvh.ncrs,
	ccbi.fingerprints.rcfunge98._3dsp,
	ccbi.fingerprints.rcfunge98.base,
	ccbi.fingerprints.rcfunge98.cpli,
	ccbi.fingerprints.rcfunge98.date,
	ccbi.fingerprints.rcfunge98.dirf,
	ccbi.fingerprints.rcfunge98.evar,
	ccbi.fingerprints.rcfunge98.file,
	ccbi.fingerprints.rcfunge98.fixp,
	ccbi.fingerprints.rcfunge98.fpdp,
	ccbi.fingerprints.rcfunge98.fpsp,
	ccbi.fingerprints.rcfunge98.frth,
	ccbi.fingerprints.rcfunge98.iipc,
	ccbi.fingerprints.rcfunge98.imap,
	ccbi.fingerprints.rcfunge98.indv,
	ccbi.fingerprints.rcfunge98.sock,
	ccbi.fingerprints.rcfunge98.strn,
	ccbi.fingerprints.rcfunge98.subr,
	ccbi.fingerprints.rcfunge98.term,
	ccbi.fingerprints.rcfunge98.time,
	ccbi.fingerprints.rcfunge98.trds;

version (Win32) alias Tuple!("TERM") TERM;
else            alias Tuple!() TERM;

alias Tuple!(
	// Cat's Eye
	"HRTI", "MODE", "MODU", "NULL", "ORTH", "PERL", "REFC", "ROMA", "TOYS",
	"TURT",

	// Jesse van Herk
	"JSTR", "NCRS",

	// RC/Funge-98
	"3DSP", "BASE", "CPLI", "DATE", "DIRF", "EVAR", "FILE", "FIXP", "FPDP",
	"FPSP", "FRTH", "IIPC", "IMAP", "INDV", "SOCK", "STRN", "SUBR", TERM,
	"TIME", "TRDS",

	// GLfunge98
	"SCKE" // Uses stuff from SOCK: must be after it in this list!
) ALL_FINGERPRINTS;

// TODO: can't these be made to use ConcatMap? Either here or at the caller

// WORKAROUND: http://d.puremagic.com/issues/show_bug.cgi?id=810
// should be below instructionsOf
//
// foreach fingerprint:
// 	case HexCode!("<fingerprint>"):
// 		return <fingerprint>Instructions!();
private template FingerprintInstructionsCases(fing...) {
	static if (fing.length)
		const FingerprintInstructionsCases =
			`case `~ToString!(HexCode!(fing[0]))~`:`
				`return `~PrefixName!(fing[0])~`Instructions!();`
			~ FingerprintInstructionsCases!(fing[1..$]);
	else
		const FingerprintInstructionsCases = "";
}

char[] instructionsOf(cell fingerprint) {
	switch (fingerprint) mixin (Switch!(
		FingerprintInstructionsCases!(ALL_FINGERPRINTS),
		"default: return null;"
	));
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
			uint _" ~fing~ "_count;
		}";
}

// foreach fingerprint:
// 	static if (is(typeof(<fingerprint>.ctor))) {
// 		case HexCode!("<fingerprint>"):
// 			if (_<fingerprint>_count == 0)
// 				<fingerprint>.ctor;
// 			_<fingerprint>_count += <fingerprint>Instructions!().length;
// 	}
template FingerprintConstructorCases(fing...) {
	static if (fing.length == 0)
		const FingerprintConstructorCases = "";
	else {
		const FingerprintConstructorCases =
			"static if (is(typeof(" ~PrefixName!(fing[0])~ ".ctor))) {
				case " ~ToString!(HexCode!(fing[0])) ~":
					if (_" ~fing[0]~"_count == 0)
						" ~PrefixName!(fing[0])~ ".ctor;
					_" ~fing[0]~"_count += "~PrefixName!(fing[0])~"Instructions!().length;
					break;
			}"
			~ FingerprintConstructorCases!(fing[1..$]);
	}
}

// foreach fingerprint:
// 	static if (is(typeof(<fingerprint>.ctor))) {
// 		case HexCode!("<fingerprint>"):
// 			--_<fingerprint>_count;
// 			assert (_<fingerprint>_count >= 0);
//
// 			static if (is(typeof(<fingerprint>.dtor))) {
// 				if (_<fingerprint>_count == 0)
// 					<fingerprint>.dtor;
// 			}
// 	}
template FingerprintDestructorCases(fing...) {
	static if (fing.length == 0)
		const FingerprintDestructorCases = "";
	else {
		const FingerprintDestructorCases =
			"static if (is(typeof(" ~PrefixName!(fing[0])~ ".ctor))) {
				case " ~ToString!(HexCode!(fing[0])) ~":
					--_" ~fing[0]~"_count;
					assert (_" ~fing[0]~"_count >= 0);

					static if (is(typeof(" ~PrefixName!(fing[0])~ ".dtor))) {
						if (_" ~fing[0]~"_count == 0)
							" ~PrefixName!(fing[0])~ ".dtor;
					}
					break;
			}"
			~ FingerprintDestructorCases!(fing[1..$]);
	}
}

// foreach fingerprint:
// 	case HexCode!("<fingerprint>"):
// 		switch (ins) mixin (Switch!(
// 			Ins!("<fingerprint>", Range!('A', 'Z')),
// 			def
// 		));
//       break;
template FingerprintExecutionCases(char[] ins, char[] def, fing...) {
	static if (fing.length)
		const FingerprintExecutionCases =
			`case `~ToString!(HexCode!(fing[0]))~`: `
				`switch (`~ins~`) mixin (Switch!(`\n\t
					`Ins!(`~Wrap!(PrefixName!(fing[0]))~`, Range!('A', 'Z')),`\n\t
					~ Wrap!(`default: `~ def) ~
				`));`\n
				`break;`\n
			~ FingerprintExecutionCases!(ins, def, fing[1..$]);
	else
		const FingerprintExecutionCases = "";
}
