// File created: 2008-09-05 15:29:14

module ccbi.fingerprints.all;

import tango.core.Tuple;

import ccbi.cell;
import ccbi.templateutils;
public import
	ccbi.fingerprints.cats_eye.null_;

alias Tuple!("NULL") ALL_FINGERPRINTS;

// WORKAROUND: http://d.puremagic.com/issues/show_bug.cgi?id=810
// should be below instructionsOf
//
// foreach fingerprint:
// 	case HexCode!("<fingerprint>"):
// 		return <fingerprint>_instructions!();
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

// foreach fingerprint:
// 	case HexCode!("<fingerprint>"):
// 		switch (ins) mixin (Switch!(
// 			mixin (Ins!("<fingerprint>", Range!('A', 'Z'))),
// 			def
// 		));
//       break;
template FingerprintExecutionCases(char[] ins, char[] def, fing...) {
	static if (fing.length)
		const FingerprintExecutionCases =
			`case `~ToString!(HexCode!(fing[0]))~`:`
				`switch (`~ins~`) mixin (Switch!(`
					`mixin (Ins!(`~Wrap!(fing[0])~`, Range!('A', 'Z'))),`
					~ Wrap!(`default: `~ def) ~
				`));`
				`break;`
			~ FingerprintExecutionCases!(ins, def, fing[1..$]);
	else
		const FingerprintExecutionCases = "";
}
