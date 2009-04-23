// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2008-08-17 11:34:45

module ccbi.templateutils;

import tango.core.Tuple;

// TODO: go over all templates here and elsewhere, make sure we're consistent
// about:
// - whether we use "static if (f.length)" or "static if (f.length == 0)", i.e.
//   is the terminating case first or last
// - const <TYPE> versus just const

/////////////////////////////////
// Hex code for finger/handprints

template HexCode(char[4] s) {
	const uint HexCode = s[3] | (s[2] << 8) | (s[1] << 16) | (s[0] << 24);
}
static assert (HexCode!("ASDF") == 0x_41_53_44_46);

////////////////
// Parse version

private template StripNonVersion(char[] s, char[] v) {
	static if (s.length == 0)
		const StripNonVersion = v;
	else static if (s[0] == '.')
		const StripNonVersion = StripNonVersion!(s[1..$], v);
	else static if (s[0] >= '0' && s[0] <= '9')
		const StripNonVersion = StripNonVersion!(s[1..$], v ~ s[0]);
	else
		const StripNonVersion = StripNonVersion!(s[1..$], "");
}

private template ActualParseVersion(char[] s) {
	static if (s.length == 0)
		const ActualParseVersion = 0;
	else {
		static assert (s[0] >= '0' && s[0] <= '9');
		const ActualParseVersion =
			Power!(int, 10, s.length-1)*(s[0] - '0')
			+ ActualParseVersion!(s[1..$]);
	}
}

template ParseVersion(char[] s) {
	const ParseVersion = ActualParseVersion!(StripNonVersion!(s, ""));
}

/////////////////////////////////////////
// Generate setters/getters to a BitArray

private template BooleansX(char[] name, uint i, B...) {
	static if (B.length == 0)
		const char[] BooleansX =
			"BitArray "~name~";"
			"void initBools() { "~name~".length = " ~ToString!(i)~ "; }";
	else {
		const char[] BooleansX =
			"bool " ~B[0]~ "()       { return "~name~"[" ~ToString!(i)~ "];     }"
			"void " ~B[0]~ "(bool x) {        "~name~"[" ~ToString!(i)~ "] = x; }"
			~ BooleansX!(name, i+1, B[1..$]);
	}
}

template Booleans(char[] name, B...) {
	static assert (B.length > 0);
	const Booleans = BooleansX!(name, 0, B);
}

//////////
// General

// Raise x to the power of n.
template Power(T, T x, T n) {
	static if (n == 0)
		const T Power = 1;
	else
		const T Power = x * Power!(T, x, n-1);
}

// Repeat x n times.
template Repeat(char[] x, uint n) {
	static if (n <= 0)
		const Repeat = "";
	else
		const Repeat = x ~ Repeat!(x, n-1);
}

// Does s contain c?
template Contains(char[] s, char c) {
	static if (s.length) {
		static if (s[0] == c)
			const Contains = true;
		else
			const Contains = Contains!(s[1..$], c);
	} else
		const Contains = false;
}

// Escape a character for placing within a character literal nested in strings
// nested to the given depth.
//
// The nesting value defaults to zero, for when there is no string.
//
// Examples:
// 	EscapeForChar!('"',  1) returns   `\"`, for   "'\"'".
// 	EscapeForChar!('\'', 1) returns `\\\'`, for "'\\\''".
// 	EscapeForChar!('\\', 1) returns `\\\\`, for "'\\\\'".
template EscapeForChar(char c, uint times = 0) {
	static if (c == '\'' || c == '\\')
		const EscapeForChar = Repeat!("\\", Power!(uint,2, times+1)-1) ~ c;
	else static if (c == '"')
		const EscapeForChar = Repeat!("\\", Power!(uint,2, times)  -1) ~ c;
	else
		const EscapeForChar = c;
}

// WORKAROUND: http://d.puremagic.com/issues/show_bug.cgi?id=810
// should be below Wrap
private template WrapHelper(char c) {
	     static if (c ==  '"') const WrapHelper = `\"`;
	else static if (c == '\\') const WrapHelper = `\\`;
	else                       const WrapHelper = c;
}

// Wrap a string in quotation marks: for instance, foo"bar\baz`qux becomes
// "foo\"bar\\baz`qux".
template Wrap(char[] s) {
	static if (Contains!(s, '"')) {
		static if (Contains!(s, '`'))
			const Wrap = `"` ~ ConcatMap!(WrapHelper, s) ~ `"`;
		else 
			const Wrap = "`" ~ s ~ "`";
	} else
		const Wrap = `"` ~ s ~ `"`;
}

template WrapAll(xs...) {
	static if (xs.length)
		alias Tuple!(Wrap!(xs[0]), WrapAll!(xs[1..$])) WrapAll;
	else
		alias xs WrapAll;
}

template ToString(ulong n, char[] suffix = n > uint.max ? "UL" : "U") {
   static if (n < 10)
		const ToString = cast(char)(n + '0') ~ suffix;
   else
		const ToString = ToString!(n/10, "") ~ ToString!(n%10, suffix);
}

template Concat(x...) {
	static if (x.length)
		const Concat = x[0] ~ Concat!(x[1..$]);
	else
		const Concat = "";
}

// WORKAROUND: http://d.puremagic.com/issues/show_bug.cgi?id=2288
template Switch(Case...) {
	const char[] Switch = "{" ~ Concat!(Case) ~ "}";
}

// Tuple!(a,b,c,d...) -> Tuple!(a,c,...)
template Firsts(T...) {
	static if (T.length) {
		static assert (T.length > 1, "Firsts :: odd list");

		alias Tuple!(T[0], Firsts!(T[2..$])) Firsts;
	} else
		alias T Firsts;
}

// All values a through b in an array. E.g. Range!(int,1,5) -> [1,2,3,4,5].
template Range(T, T a, T b) {
	// WORKAROUND: http://d.puremagic.com/issues/show_bug.cgi?id=1059
	static if (a == b)
		const T[] Range = cast(T[])[] ~ a;
	else static if (a < b)
		const T[] Range = cast(T[])[] ~ a ~ Range!(T, a+1, b);
	else
		const T[] Range = cast(T[])[] ~ b ~ Range!(T, a, b-1);

	/+
	static if (a == b)
		const T[] Range = [a];
	else static if (a < b)
		const T[] Range = [a] ~ Range!(T, a+1, b);
	else
		const T[] Range = [b] ~ Range!(T, a, b-1);
	+/
}
template Range(char a, char b) { const Range = Range!(char, a, b); }

/////////////////////
// Higher-level stuff

// mixin .s!() s: not useful in itself but handy with ConcatMap, for instance.
// Checks whether the template exists and doesn't mix it in if not.
template TemplateMixin(char[] s) {
	const TemplateMixin =
		`static if (is(typeof(.`~s~`))) mixin .`~s~`!() `~s~`;`
		`else template `~s~`() {}`;
}

template ConcatMap(alias F, char[] xs) {
	static if (xs.length)
		const ConcatMap = F!(xs[0]) ~ ConcatMap!(F, xs[1..$]);
	else
		const ConcatMap = "";
}
template ConcatMapTuple(alias F, xs...) {
	static if (xs.length)
		const ConcatMapTuple = F!(xs[0]) ~ ConcatMapTuple!(F, xs[1..$]);
	else
		const ConcatMapTuple = "";
}

// Generate a compile-time lookup table.
//
// Usage:
// 	mixin (`template Foo(arg) {` ~
// 		Lookup!("Foo", "arg", not-found-case, cases...)
// 	~ `}`);
// 
// Where cases are all strings. An even number must be given: if cases[0] ==
// arg the result is cases[1], etc.
//
// Usage is NOT:
// 	template Foo(arg) {
// 		mixin (Lookup!("Foo", "arg", not-found-case, pairs...));
// 	}
//
// If we mixin Lookup inside Foo, the whole thing is regenerated for every
// argument to Foo: compiler memory usage and compilation time goes through the
// roof.
template Lookup(char[] tmplName, char[] needle, char[] last, haystack...) {
	static if (haystack.length) {
		static assert (
			haystack.length > 1,
			"Lookup :: odd haystack for " ~ tmplName);

		const Lookup =
			"static if (" ~needle~ " == " ~haystack[0]~ ")"
				"const " ~tmplName~ " = " ~haystack[1]~ ";"
			"else " ~
				Lookup!(tmplName, needle, last, haystack[2..$]);
	} else
		const Lookup = last;
}

// Like Lookup but generates a complete template of one parameter.
template TemplateLookup(
	char[] tmplName,
	char[] needleType, char[] needle,
	char[] last,
	haystack...
) {
	const TemplateLookup =
		`template ` ~ tmplName ~ `(` ~ needleType ~ ` ` ~ needle ~ `) {` ~
			Lookup!(tmplName, needle, last, haystack)
		~ `}`;
}

// WORKAROUND: http://d.puremagic.com/issues/show_bug.cgi?id=810
// should be below RangedLookup
private template RangedLookupHelper(
	char[] tmplName,
	char[] needle,
	char[] result,
	cases...
) {
	static assert (cases.length == 1);

	static if (cases[0].length) {
		const RangedLookupHelper =
			"static if (" ~needle~ " == " ~cases[0][0] ~ ")"
				"const " ~tmplName~ " = " ~result~ ";"
			"else " ~
				RangedLookupHelper!(tmplName, needle, result, cases[0][1..$]);
	} else
		const RangedLookupHelper = "";
}

// Like Lookup but the first parts of the given pairs should be arrays, and
// each element in that array matches the second part of the pair.
//
// So given "ABC" and `"foo"`, Lookup generates essentially `ABC -> "foo"`,
// whereas RangedLookup generates `A -> "foo", B -> "foo", C -> "foo"`.
template RangedLookup(
	char[] tmplName,
	char[] needle, char[] last,
	haystack...
) {
	static if (haystack.length) {
		static assert (
			haystack.length > 1,
			"RangedLookup :: odd haystack for " ~ tmplName);

		static assert (
			is(typeof(haystack[0][0])),
			"RangedLookup :: non-indexable range in haystack");

		// RangedLookupHelper leaves a dangling "else" case
		const RangedLookup =
			RangedLookupHelper!(tmplName, needle, haystack[1], haystack[0]) ~
			RangedLookup      !(tmplName, needle, last, haystack[2..$]);
	} else
		const RangedLookup = last;
}

template TemplateRangedLookup(
	char[] tmplName,
	char[] needleType, char[] needle,
	char[] last,
	haystack...
) {
	const TemplateRangedLookup =
		`template ` ~ tmplName ~ `(` ~ needleType ~ ` ` ~ needle ~ `) {` ~
			RangedLookup!(tmplName, needle, last, haystack)
		~ `}`;
}
