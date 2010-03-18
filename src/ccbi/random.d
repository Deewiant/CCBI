// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// copyright details.

// File created: 2006-04-27 16:13:32

module ccbi.random;

import tango.math.random.engines.Twister;
import tango.time.Clock;

private Twister twister;

static this() {
	auto entropy = cast(uint)Clock.now.ticks;
	entropy -= cast(uint)&entropy;
	twister.addEntropy({return entropy;});
}

uint randomUpTo(uint MAX)() {
	const mod = uint.max - uint.max % MAX;

	uint val;
	do val = twister.next();
	while (val >= mod);

	return val % MAX;
}

uint randomUpTo(float dummy = 0)(uint max) {
	if (max == 0)
		return 0;

	auto mod = uint.max - uint.max % max;

	uint val;
	do val = twister.next();
	while (val >= mod);

	return val % max;
}
