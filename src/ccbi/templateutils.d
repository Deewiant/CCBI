// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2008-08-17 11:34:45

module ccbi.templateutils;

import tango.core.Tuple;

/////////////////////////////////
// Hex code for finger/handprints

template HexCode(char[] s) {
	static assert (s.length == 4);
	const HexCode = s[3] | (s[2] << 8) | (s[1] << 16) | (s[0] << 24);
}
static assert (HexCode!("ASDF") == 0x_41_53_44_46);

////////////////////////////////////////////
// Emit a boolean GOT_x if xs[0] in xs[1..$]

template EmitGot(xs...) {
	static if (TupleHas!(xs[0], xs[1..$]))
		const EmitGot = "enum { GOT_" ~ xs[0] ~ " = true  }";
	else
		const EmitGot = "enum { GOT_" ~ xs[0] ~ " = false }";
}

/////////////////////////////////////////
// Generate setters/getters to a BitArray

// XXX: currently unused, will we need these?
private template BooleansX(char[] name, uint i, B...) {
	static if (B.length == 0)
		const BooleansX =
			"BitArray "~name~";"
			"void initBools() { "~name~".length = " ~ToString!(i)~ "; }";
	else {
		const BooleansX =
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
	static if (s.length == 0)
		const Contains = false;
	else {
		static if (s[0] == c)
			const Contains = true;
		else
			const Contains = Contains!(s[1..$], c);
	}
}

// First element is what to search for
// Can't make this take two args for some reason...
private template TupleHas(xs...) {
	static if (xs.length <= 1)
		const TupleHas = false;
	else {
		static if (xs[0] == xs[1])
			const TupleHas = true;
		else
			const TupleHas = TupleHas!(xs[0], xs[2..$]);
	}
}

template PrefixNonNull(char[] pre, char[] s) {
	static if (s)
		const PrefixNonNull = pre ~ s;
	else
		const PrefixNonNull = s;
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
		const EscapeForChar = Repeat!("\\", Power!(uint, 2, times+1)-1) ~ c;
	else static if (c == '"')
		const EscapeForChar = Repeat!("\\", Power!(uint, 2, times)  -1) ~ c;
	else
		const EscapeForChar = c;
}

// Wrap a string in quotation marks: for instance, foo"bar\baz`qux becomes
// "foo\"bar\\baz`qux".
template Wrap(char[] s) {
	static if (Contains!(s, '"')) {
		static if (Contains!(s, '`'))
			const Wrap = `"` ~ ConcatMapString!(WrapHelper, s) ~ `"`;
		else
			const Wrap = "`" ~ s ~ "`";
	} else
		const Wrap = `"` ~ s ~ `"`;
}
private template WrapHelper(char c) {
	     static if (c ==  '"') const WrapHelper = `\"`;
	else static if (c == '\\') const WrapHelper = `\\`;
	else                       const WrapHelper = c;
}

// Hits template recursion limits unless CTFE
char[] Replace(char[] was, char[] mit, char[] s) {
	if (s.length < was.length)
		return s;
	else if (s[0 .. was.length] == was)
		return mit ~ Replace(was, mit, s[was.length .. $]);
	else
		return s[0] ~ Replace(was, mit, s[1..$]);
}

template WrapAll(xs...) {
	static if (xs.length == 0)
		alias xs WrapAll;
	else
		alias Tuple!(Wrap!(xs[0]), WrapAll!(xs[1..$])) WrapAll;
}

template ToString(ulong n, char[] suffix = n > uint.max ? "UL" : "U") {
   static if (n < 10)
		const ToString = cast(char)(n + '0') ~ suffix;
   else
		const ToString = ToString!(n/10, "") ~ ToString!(n%10, suffix);
}
// Doesn't add a 0x prefix or anything.
template ToHexString(ulong n) {
   static if (n < 10)
		const ToHexString = ""~ cast(char)(n + '0');
   else static if (n < 16)
		const ToHexString = ""~ cast(char)(n + 'a' - 10);
   else
		const ToHexString = ToHexString!(n/16) ~ ToHexString!(n%16);
}

template Concat(x...) {
	static if (x.length == 0)
		const Concat = "";
	else
		const Concat = x[0] ~ Concat!(x[1..$]);
}
template Intercalate(char[] s, x...) {
	static if (x.length > 1)
		const Intercalate = x[0] ~ s ~ Intercalate!(s, x[1..$]);

	else static if (x.length == 1)
		const Intercalate = x[0];
	else
		const Intercalate = "";
}

template Find(char c, char[] s, size_t i = 0) {
	static if (i < s.length) {
		static if (s[i] == c)
			const Find = i;
		else
			const Find = Find!(c, s, i+1);
	} else
		const Find = s.length;
}
template FindLast(char c, char[] s) {
	static if (s.length) {
		static if (s[$-1] == c)
			const FindLast = s.length - 1;
		else
			const FindLast = FindLast!(c, s[0..$-1]);
	} else
		const FindLast = s.length;
}

// Pos    ("From"): what column the wrapping started from.
// Column ("To"):   what column to start every new line from.
//
// Both are 1-based, not 0-based.
//
// s[0..wlen] is always the current word and s[wlen..$] the remainder of the
// string.
//
// Starts with a space, even if s is completely empty.
//
// Considers words as separated by one ' ', not any other whitespace or
// punctuation.
//
// CTFE because it's used in the necessarily-CTFE FEATURES in globals.
char[] WordWrapFromTo(ubyte pos, ubyte column, char[] s, ubyte wlen = 0) {
	if (s[wlen .. $] == "") {
		if (pos >= 80) {
			char[] indent;
			while (--column)
				indent ~= ' ';
			return "\n" ~ indent ~ s[0..wlen];
		} else
			return " " ~ s[0..wlen];

	} else if (s[wlen] == ' ') {
		if (pos >= 80) {
			char[] indent;
			for (auto i = column; i--;)
				indent ~= ' ';
			return
				"\n" ~ indent ~ s[0..wlen]
				     ~ WordWrapFromTo(column + wlen + 1, column, s[wlen+1 .. $]);
		} else
			return
				" " ~ s[0..wlen] ~ WordWrapFromTo(pos+1, column, s[wlen+1 .. $]);
	} else
		return WordWrapFromTo(pos+1, column, s, wlen+1);
}

// Tuple!(a,b,c,d...) -> Tuple!(a,c,...)
template Firsts(T...) {
	static if (T.length == 0)
		alias T Firsts;
	else {
		static assert (T.length > 1, "Firsts :: odd list");

		alias Tuple!(T[0], Firsts!(T[2..$])) Firsts;
	}
}

// All values a through b in an array. E.g. Range!(int,1,5) -> [1,2,3,4,5].
template Range(T, T a, T b) {
	// WORKAROUND: http://d.puremagic.com/issues/show_bug.cgi?id=1059
	static if (a == b)
		const Range = cast(T[])[] ~ a;
	else static if (a < b)
		const Range = cast(T[])[] ~ a ~ Range!(T, a+1, b);
	else
		const Range = cast(T[])[] ~ b ~ Range!(T, a, b-1);

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

// mixin .s!() s: not useful in itself but handy with ConcatMapString, for instance.
// Checks whether the template exists and doesn't mix it in if not.
template TemplateMixin(char[] s) {
	const TemplateMixin =
		`static if (is(typeof(.`~s~`))) mixin .`~s~`!() `~s~`;`
		`else template `~s~`() {}`;
}

template ConcatMapString(alias F, char[] xs) {
	static if (xs.length == 0)
		const ConcatMapString = "";
	else
		const ConcatMapString = F!(xs[0]) ~ ConcatMapString!(F, xs[1..$]);
}
template ConcatMap(alias F, xs...) {
	static if (xs.length == 0)
		const ConcatMap = "";
	else
		const ConcatMap = F!(xs[0]) ~ ConcatMap!(F, xs[1..$]);
}

template Map(alias F, xs...) {
	static if (xs.length == 0)
		alias Tuple!() Map;
	else
		alias Tuple!(F!(xs[0]), Map!(F, xs[1..$])) Map;
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
	static if (haystack.length == 0)
		const Lookup = last;
	else {
		static assert (
			haystack.length > 1,
			"Lookup :: odd haystack for " ~ tmplName);

		const Lookup =
			"static if (" ~needle~ " == " ~haystack[0]~ ")"
				"const " ~tmplName~ " = " ~haystack[1]~ ";"
			"else " ~
				Lookup!(tmplName, needle, last, haystack[2..$]);
	}
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
	static if (haystack.length == 0)
		const RangedLookup = last;
	else {
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
	}
}
private template RangedLookupHelper(
	char[] tmplName,
	char[] needle,
	char[] result,
	cases...
) {
	static assert (cases.length == 1);

	static if (cases[0].length == 0)
		const RangedLookupHelper = "";
	else {
		const RangedLookupHelper =
			"static if (" ~needle~ " == " ~cases[0][0] ~ ")"
				"const " ~tmplName~ " = " ~result~ ";"
			"else " ~
				RangedLookupHelper!(tmplName, needle, result, cases[0][1..$]);
	}
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

// Prefixes a name with _ if it's not a valid D identifier
template PrefixName(char[] name) {
	static if (name[0] >= '0' && name[0] <= '9')
		const PrefixName = "_" ~ name;
	else
		const PrefixName = name;
}
