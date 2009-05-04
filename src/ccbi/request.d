// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

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
	TIMEJUMP
}
