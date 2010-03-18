// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2008-09-06 17:16:04

module ccbi.instructions.utils;

import ccbi.templateutils;

template PushNumber(uint n) {
	const PushNumber = "cip.stack.push(" ~ ToString!(n) ~ ")";
}
