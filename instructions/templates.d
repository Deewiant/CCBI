// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2008-08-17 15:57:08

module ccbi.instructions.templates;

import ccbi.templateutils;
import ccbi.fingerprints.all; // for *InsFuncs
import ccbi.instructions.std : StdInsFunc;

import tango.core.Traits : isCallableType, ReturnTypeOf;

// WORKAROUND: http://d.puremagic.com/issues/show_bug.cgi?id=810
// should be below Ins
template SingleIns(char[] s) {
	mixin (
		// WORKAROUND http://d.puremagic.com/issues/show_bug.cgi?id=1059
		`template Single` ~s~ `Ins(char i) {
			const char[] Single` ~s~ `Ins = "
				mixin (\"
					!isCallableType!(typeof(`~s~`."~` ~s~ `InsFunc!(i)~")) ||
					is(       ReturnTypeOf!(`~s~`."~` ~s~ `InsFunc!(i)~") == void)
						? \\\"case '" ~(i=='\''?r"\\\\\\\'":i=='\\'?r"\\\\\\\\":i=='"'?"\\\\\\\"":""~i)~ "': `~s~`." ~`~
							s~`InsFunc!(i) ~"; break;\\\"
						: \\\"case '" ~(i=='\''?r"\\\\\\\'":i=='\\'?r"\\\\\\\\":i=='"'?"\\\\\\\"":""~i)~ "': `
							`return `~s~`." ~`~s~`InsFunc!(i) ~ ";\\\"` ~

//		`template Single` ~s~ `Ins(char i) {
//			const char[] Single` ~s~ `Ins = "
//				mixin (\"
//					!isCallableType!(typeof(`~s~`."~` ~s~ `InsFunc!(i)~")) ||
//					is(       ReturnTypeOf!(`~s~`."~` ~s~ `InsFunc!(i)~") == void)
//						? \\\"case '" ~EscapeForChar!(i,3)~ "': `~s~`." ~`~
//							s~`InsFunc!(i) ~"; break;\\\"
//						: \\\"case '" ~EscapeForChar!(i,3)~ "': `
//							`return `~s~`." ~`~s~`InsFunc!(i) ~ ";\\\"` ~

				// we need the trailing ~ here or we get "mixin(bar) mixin(foo)"
				// Ins appends "" so that we're not left with "mixin(bar) ~
				// mixin(foo) ~"
				`\") ~";
		}`);
}

template Ins(char[] namespace, char[] i) {
	const char[] Ins =
		mixin ("ConcatMap!(SingleIns!(namespace).Single" ~namespace~ "Ins, i)")
		~ `""`;
}
