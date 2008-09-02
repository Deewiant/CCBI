// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2008-08-17 15:57:08

module ccbi.instructions.templates;

import ccbi.templateutils;
import ccbi.instructions.std : StdInsFunc;

import tango.core.Traits : isCallableType, ReturnTypeOf;

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
//						? \\\"case '" ~Escape!(i,3)~ "': `~s~`." ~`~
//							s~`InsFunc!(i) ~"; break;\\\"
//						: \\\"case '" ~Escape!(i,3)~ "': `
//							`return `~s~`." ~`~s~`InsFunc!(i) ~ ";\\\"` ~

				// we need the trailing ~ here or we get "mixin(bar) mixin(foo)"
				// Ins appends "" so that we're not left with "mixin(bar) ~
				// mixin(foo) ~"
				`\") ~";
		}`);
}

template Ins(char[] type, char[] i) {
	const char[] Ins =
		mixin ("ConcatMap!(SingleIns!(type).Single" ~type~ "Ins, i)") ~ `""`;
}
