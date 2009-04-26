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
	ccbi.fingerprints.jvh.jstr,
	ccbi.fingerprints.jvh.ncrs,
	ccbi.fingerprints.rcfunge98.base,
	ccbi.fingerprints.rcfunge98.cpli,
	ccbi.fingerprints.rcfunge98.date,
	ccbi.fingerprints.rcfunge98.dirf;

alias Tuple!(
	// Cat's Eye
	"HRTI", "MODE", "MODU", "NULL", "ORTH", "PERL", "REFC", "ROMA", "TOYS",
	"TURT",

	// Jesse van Herk
	"JSTR", "NCRS",

	// RC/Funge-98
	"BASE", "CPLI", "DATE", "DIRF"
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
				`return `~fing[0]~`Instructions!();`
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

// <fingerprint>_count if the fingerprint has a constructor
template FingerprintCount(char[] fing) {
	const FingerprintCount =
		"static if (is(typeof(" ~fing~ ".ctor))) {
			uint " ~fing~ "_count;
		}";
}

// foreach fingerprint:
// 	static if (is(typeof(<fingerprint>.ctor))) {
// 		case HexCode!("<fingerprint>"):
// 			if (<fingerprint>_count == 0)
// 				<fingerprint>.ctor;
// 			<fingerprint>_count += <fingerprint>Instructions!().length;
// 	}
template FingerprintConstructorCases(fing...) {
	static if (fing.length == 0)
		const FingerprintConstructorCases = "";
	else {
		const FingerprintConstructorCases =
			"static if (is(typeof(" ~fing[0]~ ".ctor))) {
				case " ~ToString!(HexCode!(fing[0])) ~":
					if (" ~fing[0]~"_count == 0)
						" ~fing[0]~ ".ctor;
					" ~fing[0]~"_count += "~fing[0]~"Instructions!().length;
					break;
			}"
			~ FingerprintConstructorCases!(fing[1..$]);
	}
}

// foreach fingerprint:
// 	static if (is(typeof(<fingerprint>.ctor))) {
// 		case HexCode!("<fingerprint>"):
// 			--<fingerprint>_count;
// 			assert (<fingerprint>_count >= 0);
//
// 			static if (is(typeof(<fingerprint>.dtor))) {
// 				if (<fingerprint>_count == 0)
// 					<fingerprint>.dtor;
// 			}
// 	}
template FingerprintDestructorCases(fing...) {
	static if (fing.length == 0)
		const FingerprintDestructorCases = "";
	else {
		const FingerprintDestructorCases =
			"static if (is(typeof(" ~fing[0]~ ".ctor))) {
				case " ~ToString!(HexCode!(fing[0])) ~":
					--" ~fing[0]~"_count;
					assert (" ~fing[0]~"_count >= 0);

					static if (is(typeof(" ~fing[0]~ ".dtor))) {
						if (" ~fing[0]~"_count == 0)
							" ~fing[0]~ ".dtor;
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
					`Ins!(`~Wrap!(fing[0])~`, Range!('A', 'Z')),`\n\t
					~ Wrap!(`default: `~ def) ~
				`));`\n
				`break;`\n
			~ FingerprintExecutionCases!(ins, def, fing[1..$]);
	else
		const FingerprintExecutionCases = "";
}
