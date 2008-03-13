// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 22:49:08

module ccbi.cell;

import tango.stdc.stdint : int_fast32_t;

// separate types used so that one can just check for casts to see where one is used as the other
// some code relies on these initializers
typedef int_fast32_t
	cell = ' ',
	cellidx = 0;

// sanity check, but also mandated by the Funge-98 spec
static assert (cell.sizeof == cellidx.sizeof);
