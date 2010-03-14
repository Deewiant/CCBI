// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2008-08-17 15:57:08

module ccbi.instructions.templates;

import ccbi.templateutils;

template Ins(char[] namespace, char[] i) {
	const char[] Ins = ConcatMapIns!(MakeSingleIns!(namespace).SingleIns, i);
}

// MakeSingleIns needs these but since the compiling is elsewhere these also
// have to be imported there...
//
// This is a template and not a constant just so that it doesn't take up space
// in the executable
template InsImports() {
	const InsImports =
		"import tango.core.Traits : isCallableType, ReturnTypeOf;";
}

// MakeSingleIns!(namespace).SingleIns!(i).Ins is a string: the case statement
// for the instruction i from namespace. namespace is currently either Std or a
// fingerprint: a template.
//
// We special-case "reverse" because otherwise all fingerprint templates would
// need to add "alias Std.reverse reverse". (Except for fingerprints which
// implement all 26 instructions, of course.)
//
// We special-case anything starting with "cip.", for the PushNumber template.
template MakeSingleIns(char[] s) {
	// WORKAROUND http://d.puremagic.com/issues/show_bug.cgi?id=1059
	// Should be using EscapeForChar instead of ugly ?: mess
	// The thing was getting so unreadable that I made the C field to keep it in
	// one place, and hence ConcatMapIns

	// WORKAROUND http://d.puremagic.com/issues/show_bug.cgi?id=2339
	// Mixins the whole contents of the static ifs instead of just the typeofs

	// ` is here
	// " is in the definition
	// \" is at the use site
	mixin (
		`template SingleIns(char i) {
			const C = "'" ~ (i=='\''?r"\'":i=='\\'?r"\\":i=='"'?"\"":""~i) ~ "'";

			const Ins = "
			case "~C~":
				static if (`~s~`InsFunc!("~C~") == \"reverse\")
					return Std.reverse;

				else static if (mixin (\"!is(typeof(`~s~`))\"))
					static assert (false,
						\"SingleIns :: Need template `~s~` for instruction \"~
						`~s~`InsFunc!("~C~"));

				else static if (
					`~s~`InsFunc!("~C~").length >= 4 &&
					`~s~`InsFunc!("~C~")[0..4] == \"cip.\"
				)
					mixin (\"this.\" ~ `~s~`InsFunc!("~C~") ~ \"; break;\");

				else static if (mixin(\"
					!isCallableType!(typeof(`~s~`.\"~`~s~`InsFunc!("~C~")~\")) ||
					is(       ReturnTypeOf!(`~s~`.\"~`~s~`InsFunc!("~C~")~\") == void)
				\"))
					mixin (\"`~s~`.\" ~ `~s~`InsFunc!("~C~") ~ \"; break;\");
				else
					mixin (\"return `~s~`.\" ~ `~s~`InsFunc!("~C~") ~ \";\");
			";
		}`
	);
}

// HACK FOR WORKAROUND http://d.puremagic.com/issues/show_bug.cgi?id=1059
// See above
template ConcatMapIns(alias F, char[] xs) {
	static if (xs.length)
		const ConcatMapIns = F!(xs[0]).Ins ~ ConcatMapIns!(F, xs[1..$]);
	else
		const ConcatMapIns = "";
}
