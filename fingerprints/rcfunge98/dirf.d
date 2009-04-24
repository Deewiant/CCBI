// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:13:43

module ccbi.fingerprints.rcfunge98.dirf; private:

import tango.io.FilePath;
import tango.io.FileSystem;

import ccbi.cell;
import ccbi.fingerprint;
import ccbi.instructions : reverse;
import ccbi.utils;

// 0x44495246: DIRF
// Directory functions extension
// -----------------------------
static this() {
	mixin (Code!("DIRF"));

	fingerprints[DIRF]['C'] =& changeDir;
	fingerprints[DIRF]['M'] =& makeDir;
	fingerprints[DIRF]['R'] =& removeDir;
	
	fingerprintConstructors[DIRF] =& ctor;
}

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
