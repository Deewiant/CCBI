// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2009-09-20 12:03:27

module ccbi.space.utils;

import tango.core.Exception : onOutOfMemoryError;
import tango.stdc.stdlib    : malloc, realloc;

import ccbi.space.coords;

template Dimension(cell dim) {
	template Coords(cell x, cell y, cell z) {
		     static if (dim == 1) const Coords = .Coords!(dim)(x);
		else static if (dim == 2) const Coords = .Coords!(dim)(x,y);
		else static if (dim == 3) const Coords = .Coords!(dim)(x,y,z);
	}
	template Coords(cell x, cell y) { const Coords = Coords!(x,y,0); }
	template Coords(cell x)         { const Coords = Coords!(x,0,0); }

	package bool contains(
		.Coords!(dim) pos, .Coords!(dim) beg, .Coords!(dim) end)
	{
		foreach (i, x; pos.v)
			if (!(x >= beg.v[i] && x <= end.v[i]))
				return false;
		return true;
	}
}

package:

// We use these for AABB data mainly to keep memory usage in check. Using
// cell[] data, "data.length = foo" appears to keep the original data unfreed
// if a reallocation occurred until at least the next GC. I'm not sure if that
// was the exact cause, but using this instead of the GC can reduce worst-case
// memory usage by up to 50% in some cases. We weren't really utilizing the
// advantages of the GC anyway.
cell* cmalloc(size_t s) {
	auto p = cast(cell*)malloc(s * cell.sizeof);
	if (!p)
		onOutOfMemoryError();
	return p;
}
cell* crealloc(cell* p, size_t s) {
	p = cast(cell*)realloc(p, s * cell.sizeof);
	if (!p)
		onOutOfMemoryError();
	return p;
}

template OneCoordsLoop(
	cell dim,
	char[] c, char[] begC, char[] endC,
	char[] cmp, char[] op,
	char[] f)
{
	static if (dim == 1)
		const OneCoordsLoop =
			`for (`~c~`.x = `~begC~`.x; `~c~`.x `~cmp~endC~`.x; `~c~`.x `~op~`) {`
				~f~
			`}`;
	else static if (dim == 2)
		const OneCoordsLoop =
			`for (`~c~`.y = `~begC~`.y; `~c~`.y `~cmp~endC~`.y; `~c~`.y `~op~`)`;
	else static if (dim == 3)
		const OneCoordsLoop =
			`for (`~c~`.z = `~begC~`.z; `~c~`.z `~cmp~endC~`.z; `~c~`.z `~op~`)`;
}

template CoordsLoop(
	cell dim,
	char[] c, char[] begC, char[] endC,
	char[] cmp, char[] op,
	char[] f)
{
	static if (dim == 0)
		const CoordsLoop = "";
	else
		const CoordsLoop = OneCoordsLoop!(dim,   c, begC, endC, cmp, op, f)
		                 ~    CoordsLoop!(dim-1, c, begC, endC, cmp, op, f);
}
