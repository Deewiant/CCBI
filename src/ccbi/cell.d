// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2007-01-20 22:49:08

module ccbi.cell;

version (cell64) {
	alias  long  cell;
	alias ulong ucell;
} else {
	alias  int  cell;
	alias uint ucell;
}
