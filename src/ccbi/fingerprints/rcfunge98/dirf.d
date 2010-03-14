// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:13:43

module ccbi.fingerprints.rcfunge98.dirf;

import ccbi.fingerprint;

// 0x44495246: DIRF
// Directory functions extension
// -----------------------------

mixin (Fingerprint!(
	"DIRF",

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
