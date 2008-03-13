// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:16:38

module ccbi.fingerprints.jvh.ncrs; private:

import ccbi.fingerprint;
import ccbi.instructions : reverse;
import ccbi.ip;
import ccbi.utils;

version (Windows)
	version = PDCurses;
else
	version = ncurses;

version (PDCurses) {
	pragma (msg, "Remember to link with a PDCurses library.");
} else {
	pragma (msg, "Remember to link with an ncurses library.");
}

pragma (msg, "Assuming 32-bit chtype... correct ccbi.fingerprints.jvh.ncrs.chtype to ushort if link errors ensue.");
alias uint chtype;

extern (C) {
	struct WINDOW;

	int beep();

	int echo();
	int noecho();

	int wgetch(WINDOW*);

	WINDOW* initscr();
	int endwin();

	int keypad(WINDOW*, bool);

	int wmove(WINDOW*, int, int);

	int cbreak();
	int nocbreak();

	int wrefresh(WINDOW*);

	version (PDCurses) {
		int PDC_ungetch(int);
		alias PDC_ungetch ungetch;
	} else
		int ungetch(int);

	int waddch(WINDOW*, chtype);
	int waddstr(WINDOW*, char*);

	int werase(WINDOW*);
	int wclrtobot(WINDOW*);
	int wclrtoeol(WINDOW*);

	extern WINDOW* stdscr;
}

// 0x4e435253: NCRS
// Ncurses [sic] extension
// -----------------------

static this() {
	mixin (Code!("NCRS"));

	fingerprints[NCRS]['B'] =& doBeep;
	fingerprints[NCRS]['C'] =& clear;
	fingerprints[NCRS]['E'] =& toggleEcho;
	fingerprints[NCRS]['G'] =& get;
	fingerprints[NCRS]['I'] =& init;
	fingerprints[NCRS]['K'] =& toggleKeypad;
	fingerprints[NCRS]['M'] =& gotoxy;
	fingerprints[NCRS]['N'] =& toggleInput;
	fingerprints[NCRS]['P'] =& put;
	fingerprints[NCRS]['R'] =& refresh;
	fingerprints[NCRS]['S'] =& write;
	fingerprints[NCRS]['U'] =& unget;
}

enum { ERR = -1 }

void doBeep () { if (beep()                == ERR) reverse(); }
void refresh() { if (wrefresh(stdscr)      == ERR) reverse(); }
void unget  () { if (ungetch(ip.stack.pop) == ERR) reverse(); }

void clear() {
	switch (ip.stack.pop) {
		case 0: return werase(stdscr);
		case 1: return wclrtoeol(stdscr);
		case 2: return wclrtobot(stdscr);
		default: return reverse();
	}
}

void toggleEcho  () { if ((ip.stack.pop ? echo    () : noecho()) == ERR) reverse(); }
void toggleInput () { if ((ip.stack.pop ? nocbreak() : cbreak()) == ERR) reverse(); }
void toggleKeypad() { if (keypad(stdscr, cast(bool)ip.stack.pop) == ERR) reverse(); }

void get() { ip.stack.push(cast(cell)wgetch(stdscr)); }

void init() {
	if (ip.stack.pop) {
		if (initscr() is null)
			reverse();
	} else {
		if (endwin() == ERR)
			reverse();
	}
}

void gotoxy() {
	cellidx x, y;
	popVector(x, y);
	if (wmove(stdscr, y, x) == ERR)
		reverse();
}

void put()   { if (waddch (stdscr, cast(chtype)ip.stack.pop) == ERR) reverse(); }
void write() { if (waddstr(stdscr, cast(char*) popStringz()) == ERR) reverse(); }
