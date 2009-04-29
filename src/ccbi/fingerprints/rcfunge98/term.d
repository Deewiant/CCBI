// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-06-10 11:49:14

module ccbi.fingerprints.rcfunge98.term;

import ccbi.fingerprint;

// 0x5445524d: TERM
// Terminal control functions
// --------------------------

mixin (Fingerprint!(
	"TERM",

	"C", "clearScreen",
	"D", "goDown",
	"G", "gotoXY",
	"H", "goHome",
	"L", "clearToEOL",
	"S", "clearToEOS",
	"U", "goUp"
));

version (Win32) {

template TERM() {
	import tango.core.Exception : IOException;
	import tango.sys.win32.UserGdi;

	CONSOLE_SCREEN_BUFFER_INFO csbi;
	HANDLE stdout;

	void ctor() {
		stdout = GetStdHandle(STD_OUTPUT_HANDLE);
		if (stdout is null)
			throw new IOException("TERM :: ctor couldn't get STD_OUTPUT_HANDLE");
	}

	// straight from http://msdn2.microsoft.com/en-us/library/ms682022.aspx
	void clearScreen() {
		Sout.flush;

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
		Sout.flush;

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
		Sout.flush;

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
		auto n = cip.stack.pop;

		if (!GetConsoleScreenBufferInfo(stdout, &csbi))
			return reverse();

		xy(csbi.dwCursorPosition.X, csbi.dwCursorPosition.Y + n);
	}
	void goUp() {
		auto n = cip.stack.pop;

		if (!GetConsoleScreenBufferInfo(stdout, &csbi))
			return reverse();

		xy(csbi.dwCursorPosition.X, csbi.dwCursorPosition.Y - n);
	}
	void goHome() {
		xy(0, 0);
	}
	void gotoXY() {
		auto y = cip.stack.pop;
		xy(cip.stack.pop, y);
	}

	private void xy(DWORD x, DWORD y) {
		Sout.flush;

		if (!SetConsoleCursorPosition(stdout, COORD(x, y)))
			reverse();
	}

}
} else version (Posix) {

extern (C) {
	alias int c_int; // Valid for all D-supported platforms?

	char* tigetstr        (char*);
	c_int tputs           (char*, c_int, c_int function(c_int));
	char* tparm           (char*, ...);
	c_int reset_shell_mode();
	c_int def_shell_mode  ();
	c_int setupterm       (char*, c_int, c_int*);
}

template TERM() {
	import tango.core.Exception : IOException;
	import tango.stdc.stdio  : fileno, stdout;
	import tango.stdc.stringz;
	import tango.text.convert.Integer : toString;

	pragma (msg, "TERM :: assuming we have a terminfo database...");

	extern (C) static int my_putchar(int x) {
		Sout(cast(char)x);
		return 0;
	}
	void putp(char* s) {
		tputs(s, 1, &my_putchar);
	}

	char*
		enter_ca_mode,
		exit_ca_mode,
		clear_screen,
		clear_eol,
		clear_eos,
		go_home,
		go_down,
		go_up,
		go_xy;

	char* tryLoad(char* s) {
		auto res = tigetstr(s);
		if (res == cast(char*)-1)
			throw new IOException(
				"TERM :: couldn't load " ~ fromStringz(s) ~ " from terminfo");
		return res;
	}
	void ctor() {
		int err = void;
		setupterm(null, fileno(stdout), &err);
		if (err != 1)
			throw new IOException(
				"TERM :: failed to gain access to terminfo "
				"(setupterm reported " ~ toString(err) ~ ")");

		if (!enter_ca_mode) {
			clear_screen  = tryLoad("clear");
			clear_eol     = tryLoad("el");
			clear_eos     = tryLoad("ed");
			go_home       = tryLoad("home");
			go_down       = tryLoad("cud");
			go_up         = tryLoad("cuu");
			go_xy         = tryLoad("cup");
   		enter_ca_mode = tryLoad("smcup");
		}

   	putp(enter_ca_mode);
	}
	void dtor() {
		if (!exit_ca_mode)
			exit_ca_mode = tryLoad("rmcup");

		putp(exit_ca_mode);
		reset_shell_mode();
	}

	void clearScreen() { putp(clear_screen); }
	void clearToEOL () { putp(clear_eol);    }
	void clearToEOS () { putp(clear_eos);    }
	void goHome     () { putp(go_home);      }
	void goDown     () {
		auto n = cip.stack.pop;
		if (n < 0)
			goUp(-n);
		else if (n > 0)
			goDown(n);
	}
	void goUp() {
		auto n = cip.stack.pop;
		if (n < 0)
			goDown(-n);
		else if (n > 0)
			goUp(n);
	}
	void goDown(cell n) { tryPutp(tparm(go_down, n)); }
	void goUp  (cell n) { tryPutp(tparm(go_up,   n)); }

	void gotoXY() {
		auto y = cip.stack.pop,
		     x = cip.stack.pop;
		tryPutp(tparm(go_xy, y, x));
	}

	void tryPutp(char* s) { s ? putp(s) : reverse; }
}
}
