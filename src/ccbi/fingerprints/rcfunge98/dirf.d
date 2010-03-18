// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2007-01-20 21:13:43

module ccbi.fingerprints.rcfunge98.dirf;

import ccbi.fingerprint;

mixin (Fingerprint!(
	"DIRF",
	"Directory functions extension",

	"C", "changeDir",
	"M", "makeDir",
	"R", "removeDir"
));

template DIRF() {

// Selective import is:
// WORKAROUND: http://d.puremagic.com/issues/show_bug.cgi?id=2991
import tango.io.FilePath : FilePath;
import tango.sys.Environment;

FilePath path;

void ctor() {
	path = new FilePath(Environment.cwd());
	path.native;
}

void changeDir() {
	try {
		Environment.cwd = popString();
		path.set(Environment.cwd()).native;
	} catch { reverse(); }
}

void makeDir() {
	try (new FilePath(popString())).native.createFolder();
	catch { reverse(); }
}

void removeDir() {
	try {
		auto dir = new FilePath(popString());
		dir.native;
		if (dir.isFolder())
			dir.remove();
		else
			reverse();
	} catch { reverse(); }
}

}
