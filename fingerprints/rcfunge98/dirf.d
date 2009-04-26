// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:13:43

module ccbi.fingerprints.rcfunge98.dirf;

import ccbi.fingerprint;

// Both WORKAROUND: http://www.dsource.org/projects/dsss/ticket/175
import tango.io.FilePath;
import tango.io.FileSystem;

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

import tango.io.FilePath;
import tango.io.FileSystem;

FilePath path;

void ctor() {
	path = new FilePath(FileSystem.getDirectory());
	path.native;
}

void changeDir() {
	try {
		FileSystem.setDirectory(popString());
		path.set(FileSystem.getDirectory()).native;
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
