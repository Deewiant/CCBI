// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:16:38

module ccbi.fingerprints.jvh.ncrs;

import ccbi.fingerprint;

pragma (msg, "NCRS :: assuming 32-bit chtype...");
alias uint chtype;

alias int c_int;

extern (C) {
	ubyte ccbi_beep();
	ubyte ccbi_refresh();

	ubyte ccbi_erase();
	ubyte ccbi_clrtobot();
	ubyte ccbi_clrtoeol();

	ubyte ccbi_echo  (c_int);
	ubyte ccbi_cbreak(c_int);
	ubyte ccbi_keypad(c_int);

	c_int ccbi_getch();
	ubyte ccbi_ungetch(c_int);

	ubyte ccbi_initscr();
	ubyte ccbi_endwin();

	ubyte ccbi_move(c_int, c_int);

	ubyte ccbi_addch (chtype);
	ubyte ccbi_addstr(/+const+/ char*);
}
version (Windows) {
	pragma (msg,
		"NCRS :: remember to link with a curses library, such as PDCurses.");
} else
	pragma (msg,
		"NCRS :: remember to link with a curses library, such as ncurses.");

// 0x4e435253: NCRS
// Ncurses [sic] extension
// -----------------------

mixin (Fingerprint!(
	"NCRS",

	"B", "beep",
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

template NCRS() {

void beep   () { if (!ccbi_beep())    reverse; }
void refresh() { if (!ccbi_refresh()) reverse; }

void clear() {
	switch (cip.stack.pop) {
		case 0: if (!ccbi_erase   ()) reverse; return;
		case 1: if (!ccbi_clrtoeol()) reverse; return;
		case 2: if (!ccbi_clrtobot()) reverse; return;
		default: return reverse;
	}
}

void toggleEcho  () { if (!ccbi_echo  (cip.stack.pop)) reverse; }
void toggleInput () { if (!ccbi_cbreak(cip.stack.pop)) reverse; }
void toggleKeypad() { if (!ccbi_keypad(cip.stack.pop)) reverse; }

void   get() { cip.stack.push(cast(cell)ccbi_getch()); }
void unget() { if (!ccbi_ungetch(cip.stack.pop)) reverse; }

void init() {
	if (cip.stack.pop) {
		if (!ccbi_initscr())
			reverse();
	} else {
		if (!ccbi_endwin())
			reverse();
	}
}

void gotoxy() {
	cell y = cip.stack.pop;
	if (!ccbi_move(y, cip.stack.pop))
		reverse();
}

void put()   { if (!ccbi_addch (cast(chtype)cip.stack.pop)) reverse; }
void write() { if (!ccbi_addstr(popStringz()))              reverse; }

}
