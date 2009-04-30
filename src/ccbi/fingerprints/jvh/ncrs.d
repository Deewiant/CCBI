// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:16:38

module ccbi.fingerprints.jvh.ncrs;

import ccbi.fingerprint;

version (Windows)
	version = PDCurses;
else
	version = ncurses;

template ChtypeMsg() { const ChtypeMsg = "NCRS :: assuming 32-bit chtype..."; }
alias uint chtype;

template MacroMsg() { const MacroMsg =
"NCRS :: echo, noecho, and initscr may be macros, but there's no other way to
        get their functionality than using them. Since both PDCurses and
        ncurses provide them as actual functions, assuming that your curses
        implementation also does so..."; }

extern (C) {
	struct WINDOW;

	int beep();

	// may be macros
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

pragma (msg, ChtypeMsg!());
pragma (msg, MacroMsg!());

version (PDCurses) {
	pragma (msg,
		"NCRS :: remember to link with a curses library, such as PDCurses.");
} else {
	pragma (msg,
		"NCRS :: remember to link with a curses library, such as ncurses.");
}

void doBeep () { if (beep()                 == ERR) reverse; }
void refresh() { if (wrefresh(stdscr)       == ERR) reverse; }
void unget  () { if (ungetch(cip.stack.pop) == ERR) reverse; }

void clear() {
	switch (cip.stack.pop) {
		case 1: return wclrtoeol(stdscr);
		case 0:
			// return werase(stdscr); may be a macro, so do it manually
			if (wmove(stdscr, 0, 0) == ERR)
				reverse;
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
