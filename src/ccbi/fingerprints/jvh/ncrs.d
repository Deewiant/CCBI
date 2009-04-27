// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:16:38

module ccbi.fingerprints.jvh.ncrs;

import ccbi.fingerprint;

version (Windows)
	version = PDCurses;
else
	version = ncurses;

version (PDCurses) {
	pragma (msg, "Remember to link with a PDCurses library.");
} else {
	pragma (msg, "Remember to link with an ncurses library.");
}

pragma (msg, "Assuming 32-bit chtype...");
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

mixin (Fingerprint!(
	"NCRS",

	"B", "doBeep",
	"C", "clear",
	"E", "toggleEcho",
	"G", "get",
	"I", "init",
	"K", "toggleKeypad",
	"M", "gotoxy",
	"N", "toggleInput",
	"P", "put",
	"R", "refresh",
	"S", "write",
	"U", "unget"
));

enum { ERR = -1 }

template NCRS() {

void doBeep () { if (beep()                 == ERR) reverse; }
void refresh() { if (wrefresh(stdscr)       == ERR) reverse; }
void unget  () { if (ungetch(cip.stack.pop) == ERR) reverse; }

void clear() {
	switch (cip.stack.pop) {
		case 0: return werase(stdscr);
		case 1: return wclrtoeol(stdscr);
		case 2: return wclrtobot(stdscr);
		default: return reverse();
	}
}

void toggleEcho  () { if ((cip.stack.pop ? echo    () : noecho()) == ERR) reverse; }
void toggleInput () { if ((cip.stack.pop ? nocbreak() : cbreak()) == ERR) reverse; }
void toggleKeypad() { if (keypad(stdscr, cast(bool)cip.stack.pop) == ERR) reverse; }

void get() { cip.stack.push(cast(cell)wgetch(stdscr)); }

void init() {
	if (cip.stack.pop) {
		if (initscr() is null)
			reverse();
	} else {
		if (endwin() == ERR)
			reverse();
	}
}

void gotoxy() {
	cell y = cip.stack.pop;
	if (wmove(stdscr, y, cip.stack.pop) == ERR)
		reverse();
}

void put()   { if (waddch (stdscr, cast(chtype)cip.stack.pop) == ERR) reverse; }
void write() { if (waddstr(stdscr, popStringz())              == ERR) reverse; }

}
