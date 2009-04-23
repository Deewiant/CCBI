// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-06-10 11:49:14

module ccbi.fingerprints.rcfunge98.term; private:

import tango.core.Exception       : IOException;
import tango.io.Stdout            : Stdout;
import tango.sys.Common;
import tango.text.convert.Integer : format;

import ccbi.fingerprint;
import ccbi.instructions : reverse;
import ccbi.ip;

// 0x5445524d: TERM
// Terminal control functions
// --------------------------

version (Win32) {
static this() {
	mixin (Code!("TERM"));

	fingerprints[TERM]['C'] =& clearScreen;
	fingerprints[TERM]['D'] =& goDown;
	fingerprints[TERM]['G'] =& gotoXY;
	fingerprints[TERM]['H'] =& goHome;
	fingerprints[TERM]['L'] =& clearToEOL;
	fingerprints[TERM]['S'] =& clearToEOS;
	fingerprints[TERM]['U'] =& goUp;

	fingerprintConstructors[TERM] =& ctor;

	version (Posix)
		fingerprintDestructors[TERM] =& dtor;
}
}

version (Win32) {
	CONSOLE_SCREEN_BUFFER_INFO csbi;
	HANDLE stdout;

	void ctor() {
		stdout = GetStdHandle(STD_OUTPUT_HANDLE);
		if (stdout is null)
			throw new IOException("TERM ctor couldn't get STD_OUTPUT_HANDLE");
	}

	// straight from http://msdn2.microsoft.com/en-us/library/ms682022.aspx
	void clearScreen() {
		Stdout.stream.flush;

		if (!GetConsoleScreenBufferInfo(stdout, &csbi))
			return reverse();

		auto bufferSize = csbi.dwSize.X * csbi.dwSize.Y;

		DWORD charsWritten;

		const COORD homePos = {0,0};

		if (!FillConsoleOutputCharacterA(stdout, ' ', bufferSize, homePos, &charsWritten))
			return reverse();

		if (!GetConsoleScreenBufferInfo(stdout, &csbi))
			return reverse();

		if (!FillConsoleOutputAttribute(stdout, csbi.wAttributes, bufferSize, homePos, &charsWritten))
			return reverse();

		goHome();
	}
	void clearToEOL() {
		Stdout.stream.flush;

		if (!GetConsoleScreenBufferInfo(stdout, &csbi))
			return reverse();

		DWORD charsWritten;

		auto bufferSize = csbi.dwSize.X - csbi.dwCursorPosition.X;

		if (!FillConsoleOutputCharacterA(stdout, ' ', bufferSize, csbi.dwCursorPosition, &charsWritten))
			return reverse();

		if (!GetConsoleScreenBufferInfo(stdout, &csbi))
			return reverse();

		if (!FillConsoleOutputAttribute(stdout, csbi.wAttributes, bufferSize, csbi.dwCursorPosition, &charsWritten))
			return reverse();
	}
	void clearToEOS() {
		Stdout.stream.flush;

		if (!GetConsoleScreenBufferInfo(stdout, &csbi))
			return reverse();

		DWORD charsWritten;

		auto bufferSize = csbi.dwSize.X * (csbi.dwSize.Y - csbi.dwCursorPosition.Y) - csbi.dwCursorPosition.X;

		if (!FillConsoleOutputCharacterA(stdout, ' ', bufferSize, csbi.dwCursorPosition, &charsWritten))
			return reverse();

		if (!GetConsoleScreenBufferInfo(stdout, &csbi))
			return reverse();

		if (!FillConsoleOutputAttribute(stdout, csbi.wAttributes, bufferSize, csbi.dwCursorPosition, &charsWritten))
			return reverse();
	}

	void goDown() {
		auto n = ip.stack.pop;

		if (!GetConsoleScreenBufferInfo(stdout, &csbi))
			return reverse();

		xy(csbi.dwCursorPosition.X, csbi.dwCursorPosition.Y + n);
	}
	void goUp() {
		auto n = ip.stack.pop;

		if (!GetConsoleScreenBufferInfo(stdout, &csbi))
			return reverse();

		xy(csbi.dwCursorPosition.X, csbi.dwCursorPosition.Y - n);
	}
	void goHome() {
		xy(0, 0);
	}
	void gotoXY() {
		auto y = ip.stack.pop;
		xy(ip.stack.pop, y);
	}

	private void xy(DWORD x, DWORD y) {
		Stdout.stream.flush;

		if (!SetConsoleCursorPosition(stdout, COORD(x, y)))
			reverse();
	}

} else version (Posix) {
	pragma (
		msg,
		"Sorry, the TERM fingerprint isn't supported on Posix because I can't "
		"get term.h functionality to work the way it should. If you think you "
		"can, feel free to let me know.");

	/+import tango.stdc.config : c_long;
	import tango.stdc.stdio  : fileno, stdout;
	import tango.stdc.stringz;
	import tango.text.convert.Integer : toString;

	pragma (msg, "Assuming the host machine has a terminfo database...");

	extern (C) {
		char* tigetstr        (char*);
		int   tputs           (char*, int, int function(int));
		char* tparm           (char*, c_long, c_long, c_long, c_long, c_long, c_long, c_long, c_long, c_long);
		int   reset_shell_mode();
		int   def_shell_mode  ();
		int   setupterm       (char*, int, int*);
	}

	extern (C) int my_putchar(int x) {
		Stdout(cast(char)x);
		return 0;
	}
	void putp(char* s) {
		tputs(s, 1, &my_putchar);
	}

	char*
		clear_screen,
		clear_eol,
		clear_eos,
		go_home,
		go_down,
		go_up,
		go_xy;

	void try_load(out char* s, char* x) {
		s = tigetstr(x);
		if (s == cast(char*)-1)
			throw new IOException("TERM :: couldn't load " ~ fromStringz(x) ~ " from terminfo");
	}
	void ctor() {
		int err = void;
		setupterm(null, fileno(stdout), &err);
		if (err != 1)
			throw new IOException("TERM :: failed to gain access to terminfo (setupterm reported " ~ toString(err) ~ ")");

		try_load(clear_screen, "clear");
		try_load(clear_eol   , "el");
		try_load(clear_eos   , "ed");
		try_load(go_home     , "home");
		try_load(go_down     , "cud1");
		try_load(go_up       , "cuu1");
		try_load(go_xy       , "cup");

   	char* enter_ca_mode;
   	try_load(enter_ca_mode, "smcup");
   	putp(enter_ca_mode);
	}
	void dtor() {
		char* exit_ca_mode;
		try_load(exit_ca_mode, "rmcup");
		putp(exit_ca_mode);
		reset_shell_mode();
	}

	void clearScreen() { putp(clear_screen); }
	void clearToEOL () { putp(clear_eol);    }
	void clearToEOS () { putp(clear_eos);    }
	void goHome     () { putp(go_home);      }
	void goDown     () { putp(go_down);      }
	void goUp       () { putp(go_up);        }

	void gotoXY() {
		auto y = ip.stack.pop,
		     x = ip.stack.pop;
		char* s = tparm(go_xy, y, x, 0, 0, 0, 0, 0, 0, 0);
		if (s)
			putp(s);
		else
			reverse();
	}+/
}
