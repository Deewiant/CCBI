// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2008-08-23 13:48:00

// Request: a simple 'what to do next' enum.
module ccbi.request;

// The most common value is MOVE, the default after executing an instruction.
enum Request {
	NONE,
	MOVE,
	STOP,
	QUIT,
	FORK,
	RETICK
}
