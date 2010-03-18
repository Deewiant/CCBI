// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2009-09-15 19:20:52

module ccbi.exceptions;

class InfiniteLoopException : Exception {
	char[] detector;
	this(char[] d, char[] msg) {
		detector = d;
		super(msg);
	}
}

final class SpaceInfiniteLoopException : InfiniteLoopException {
	this(char[] src, char[] pos, char[] delta, char[] msg) {
		super(src ~ " at " ~ pos ~ " with delta " ~ delta, msg);
	}
}
