// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2008-08-17 11:34:45

module ccbi.templateutils;

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
		const char[] StripNonVersion = v;
	else static if (s[0] == '.')
		const char[] StripNonVersion = StripNonVersion!(s[1..$], v);
	else static if (s[0] >= '0' && s[0] <= '9')
		const char[] StripNonVersion = StripNonVersion!(s[1..$], v ~ s[0]);
	else
		const char[] StripNonVersion = StripNonVersion!(s[1..$], "");
}

private template ActualParseVersion(char[] s) {
	static if (s.length == 0)
		const int ActualParseVersion = 0;
	else {
		static assert (s[0] >= '0' && s[0] <= '9');
		const int ActualParseVersion =
			Power!(int, 10, s.length-1)*(s[0] - '0')
			+ ActualParseVersion!(s[1..$]);
	}
}

template ParseVersion(char[] s) {
	const int ParseVersion = ActualParseVersion!(StripNonVersion!(s, ""));
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

private template Power(T, T x, T n) {
	static if (n == 0)
		const T Power = 1;
	else
		const T Power = x * Power!(T, x, n-1);
}

private template Repeat(T, T x, uint n) {
	static if (n <= 0)
		const T[] Repeat = [];
	else
		const T[] Repeat = x ~ Repeat!(T, x, n-1);
}

// Escape a character for placing within strings nested to the given depth.
//
// For instance: Escape!('"', 1) returns `\"`.
template Escape(char c, uint times = 1) {
	static if (c == '\'')
		const Escape = Repeat!(char, '\\', Power!(uint, 2, times)  -1) ~ c;
	else static if (c == '\\')
		const Escape = Repeat!(char, '\\', Power!(uint, 2, times))     ~ c;
	else static if (c == '"')
		const Escape = Repeat!(char, '\\', Power!(uint, 2, times-1)-1) ~ c;
	else
		const Escape = c;
}

template ToString(ulong n, char[] suffix = n > uint.max ? "UL" : "U") {
   static if (n < 10)
		const ToString = cast(char)(n + '0') ~ suffix;
   else
		const ToString = ToString!(n/10, "") ~ ToString!(n%10, suffix);
}

template ConcatMap(alias F, char[] i) {
	static if (i.length)
		const char[] ConcatMap = F!(i[0]) ~ ConcatMap!(F, i[1..$]);
	else
		const char[] ConcatMap = "";
}

template Concat(x...) {
	static if (x.length)
		const char[] Concat = x[0] ~ Concat!(x[1..$]);
	else
		const char[] Concat = "";
}

// WORKAROUND: http://d.puremagic.com/issues/show_bug.cgi?id=2288
template Switch(Case...) {
	const char[] Switch = "{" ~ Concat!(Case) ~ "}";
}

// Generate a compile-time lookup table.
//
// Usage:
// 	mixin (`template Foo(arg) {` ~
// 		Lookup!("Foo", "arg", not-found-case, pairs...)
// 	~ `}`);
// 
// Where pairs are array literals with two strings each, such as those given by
// P!() (see below).
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
		static assert (haystack[0].length == 2, "Lookup :: odd haystack");

		const char[] Lookup =
			"static if (" ~needle~ " == " ~haystack[0][0]~ ")
				const char[] " ~tmplName~ " = " ~haystack[0][1]~ ";
			else " ~
				Lookup!(tmplName, needle, last, haystack[1..$]);
	} else
		const char[] Lookup = last;
}

// helper for Lookup: makes one haystack pair out of a char and char[]
template P(char i, char[] f) {
	static if (i == '\'' || i == '\\')
		const char[][] P = ["'\\"~i~"'", "`"~f~"`"];
	else
		const char[][] P = ["'"~i~"'", "`"~f~"`"];
}

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
