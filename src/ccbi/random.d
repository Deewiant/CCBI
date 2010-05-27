// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// copyright details.

// File created: 2006-04-27 16:13:32

module ccbi.random;

import tango.math.random.Twister;

// [0,N.max] for integral, [0,1) for floating
N random(N)() {
	static if (is(N == uint))
		return Twister.instance.natural();

	else static if (is(N == ulong))
		return cast(ulong)random!(uint) << 32 | random!(uint);

	else static if (is(N == float) || is(N == double))
		return cast(N)Twister.instance.fraction();

	else
		static assert (false, N.stringof);
}

// [0,MAX)
U randomUpTo(U, U MAX)() {
	static assert (is(U == uint) || is(U == ulong));
	static assert (MAX > 0 && MAX < U.max);

	const mod = U.max - U.max % MAX;

	U val;
	do val = random!(U);
	while (val >= mod);

	return val % MAX;
}

// [0,max)
U randomUpTo(U, float dummy = 0)(U max) {
	static assert (is(U == uint) || is(U == ulong));

	if (max == 0)
		return 0;

	if (max == U.max)
		return random!(U)();

	auto mod = U.max - U.max % max;

	U val;
	do val = random!(U);
	while (val >= mod);

	return val % max;
}

void reseed()       { Twister.instance.seed(); }
void reseed(uint s) { Twister.instance.seed(s); }
