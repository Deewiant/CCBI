// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 20:13:49

// Stuff related to fingerprints, and some Mini-Funge variables which have to
// be defined outside ccbi.minifunge to avoid circular dependencies.
module ccbi.fingerprint;

import tango.core.Tuple;

public import ccbi.cell;
       import ccbi.templateutils;

template Code(char[4] s, char[] id = s) {
	const Code =
		"const cell " ~ id ~ " = " ~ ToString!(HexCode!(s)) ~ ";" ~
		// this really shouldn't be here, but oh well
		"fingerprints[" ~ ToString!(HexCode!(s)) ~ "] = " ~
		"new typeof(fingerprints[" ~ ToString!(HexCode!(s)) ~ "])('Z'+1);";
}

// WORKAROUND: http://d.puremagic.com/issues/show_bug.cgi?id=810
// should be below WrapForCasing
//
// "ABC" -> ["'A'","'B'","'C'"]
private template WrapForCasingHelper(char[] s) {
	static if (s.length)
		const char[][] WrapForCasingHelper =
			// WORKAROUND: http://d.puremagic.com/issues/show_bug.cgi?id=1640
			// outer brackets are a Rebuild workaround
			(["'" ~EscapeForChar!(s[0],1)~ "'"]) ~ WrapForCasingHelper!(s[1..$]);
	else
		const char[][] WrapForCasingHelper = [];
}

// WORKAROUND: http://d.puremagic.com/issues/show_bug.cgi?id=810
// should be below Fingerprint
//
// Tuple!("ABC", "blaa") -> Tuple!(["'A'","'B'","'C'"], `"blaa"`)
private template WrapForCasing(ins...) {
	static if (ins.length) {
		static assert (ins.length > 1, "WrapForCasing :: odd list");

		alias Tuple!(
			WrapForCasingHelper!(ins[0]),
			Wrap               !(ins[1]),
			WrapForCasing      !(ins[2..$])
		) WrapForCasing;
	} else
		alias ins WrapForCasing;
}

// Generates two templates given "fing":
//
// template fingInsFunc(cell c) {
// 	static if (c == ...) const fingInsFunc = ...;
// 	...
// 	else const fingInsFunc = "reverse";
// }
//
// template fingInstructions() { const fingInstructions = "ABC..."; }
template Fingerprint(char[] name, ins...) {
	const Fingerprint =
		TemplateRangedLookup!(
			name ~ "InsFunc",
			"cell", "c",
			"const "~name~"InsFunc = `reverse`;",
			WrapForCasing!(ins)
		) ~
		"template "~name~"Instructions() {"
			"const "~name~"Instructions = "
				~ ConcatMapTuple!(Wrap, Firsts!(ins)) ~ ";"
		"}";
}

struct Semantics {
	cell fingerprint;
	
	// Needed for FING/FNGR, since you can't just tell from the instruction
	// being executed: 'A' in QWFP might be mapped to 'B' in ARST
	char instruction;
}