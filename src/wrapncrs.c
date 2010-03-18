/* This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
 * Copyright (c) 2006-2010 Matti Niemenmaa
 * See license.txt, which you should have received together with this file, for
 * copyright details.
 */

/* File created: 2010-02-27 11:34:18 */

#include <curses.h>
#include <stdint.h>

/* echo, noecho, and initscr may be macros, so wrap them here.
 *
 * In PDCurses, ungetch is a macro as well, even though the XSI Curses standard
 * doesn't allow for it. So to be safe, just wrap everything here.
 */

#define chk(x) ((x) == ERR ? 0 : 1)

uint8_t ccbi_beep() { return chk(beep()); }

/* initscr has the annoying habit of exit(3)-killing the whole program on
 * failure: do setupterm first, since it doesn't do that, and this may let us
 * catch an error earlier. Check for initscr() being NULL anyway, in case the
 * implementation is of the nice kind.
 */
uint8_t ccbi_initscr() {
	int err;
	if (setupterm(NULL, 1, &err) == ERR)
		return 0;
	return initscr() == NULL ? 0 : 1;
}
uint8_t ccbi_endwin() { return chk(endwin()); }

uint8_t ccbi_cbreak(int on) { return chk(on ? nocbreak() : cbreak()); }
uint8_t ccbi_echo  (int on) { return chk(on ? echo() : noecho()); }
uint8_t ccbi_keypad(int on) { return chk(keypad(stdscr, on)); }

uint8_t ccbi_move(int y, int x) { return chk(move(y, x)); }

uint8_t ccbi_refresh() { return chk(refresh()); }

int     ccbi_getch  ()      { return getch(); }
uint8_t ccbi_ungetch(int c) { return chk(ungetch(c)); }

uint8_t ccbi_addch (chtype c)      { return chk(addch (c)); }
uint8_t ccbi_addstr(const char* s) { return chk(addstr(s)); }

uint8_t ccbi_erase   () { return chk(erase   ()); }
uint8_t ccbi_clrtobot() { return chk(clrtobot()); }
uint8_t ccbi_clrtoeol() { return chk(clrtoeol()); }
