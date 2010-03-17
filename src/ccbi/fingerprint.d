// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 20:13:49

// Stuff related to fingerprints.
module ccbi.fingerprint;

import tango.core.Tuple;

public import ccbi.cell;
       import ccbi.templateutils;

// Generates three templates given "fing":
//
// template fingDesc() { const fingDesc = desc; }
//
// template fingInsFunc(cell c) {
// 	static if (c == ...) const fingInsFunc = ...;
// 	...
// 	else const fingInsFunc = "reverse";
// }
//
// template fingInstructions() { const fingInstructions = "ABC..."; }
template Fingerprint(char[] name, char[] desc, ins...) {
	const Fingerprint =
		"template "~PrefixName!(name)~"Desc() {"
			"const "~PrefixName!(name)~"Desc = " ~Wrap!(desc)~ ";"
		"}" ~
		TemplateRangedLookup!(
			PrefixName!(name) ~ "InsFunc",
			"cell", "c",
			"const "~PrefixName!(name)~"InsFunc = `reverse`;",
			WrapForCasing!(ins)
		) ~
		"template "~PrefixName!(name)~"Instructions() {"
			"const "~PrefixName!(name)~"Instructions = "
				~ ConcatMap!(Wrap, Firsts!(ins)) ~ ";"
		"}";
}
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
// "ABC" -> ["'A'","'B'","'C'"]
private template WrapForCasingHelper(char[] s) {
	static if (s.length)
		const char[][] WrapForCasingHelper =
			"'" ~EscapeForChar!(s[0],1)~ "'" ~ WrapForCasingHelper!(s[1..$]);
	else
		const char[][] WrapForCasingHelper = [];
}

struct Semantics {
	cell fingerprint;

	// Needed for FING/FNGR, since you can't just tell from the instruction
	// being executed: 'A' in QWFP might be mapped to 'B' in ARST
	char instruction;
}
