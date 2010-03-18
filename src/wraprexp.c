/* This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
 * Copyright (c) 2006-2010 Matti Niemenmaa
 * See license.txt, which you should have received together with this file, for
 * copyright details.
 */

/* File created: 2010-03-12 21:43:20 */

#include <regex.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

/* Platform-specificity:
 * 	regex_t
 * 	regmatch_t
 * 	the values of the flags passed to regcomp and regex
 * 	the values of the errors returned by regcomp and regexec
 *
 * So we need the C wrapper.
 */

/* Yay unspecified magic constants */
enum { MATCH_COUNT = 256 };

/* Ideally conversions between these two are optimized away */
struct ccbi_regmatch_t { ptrdiff_t rm_so, rm_eo; };
union Matches {
	            regmatch_t      matches[MATCH_COUNT];
	struct ccbi_regmatch_t ccbi_matches[MATCH_COUNT];
};
union Matches matches;

enum {
	CCBI_REG_EXTENDED = 1,
	CCBI_REG_ICASE    = 2,
	CCBI_REG_NOSUB    = 4,
	CCBI_REG_NEWLINE  = 8,

	CCBI_REG_NOTBOL = 1,
	CCBI_REG_NOTEOL = 2,

	CCBI_REG_BADBR    = 1,
	CCBI_REG_BADPAT   = 2,
	CCBI_REG_BADRPT   = 3,
	CCBI_REG_EBRACE   = 4,
	CCBI_REG_EBRACK   = 5,
	CCBI_REG_ECOLLATE = 6,
	CCBI_REG_ECTYPE   = 7,
	CCBI_REG_EEND     = 8,
	CCBI_REG_EESCAPE  = 9,
	CCBI_REG_EPAREN   = 10,
	CCBI_REG_ERANGE   = 11,
	CCBI_REG_ESIZE    = 12,
	CCBI_REG_ESPACE   = 13,
	CCBI_REG_ESUBREG  = 14,
};

static regex_t regex;

uint8_t ccbi_compile(const char* pat, uint8_t ccbiFlags) {

	int flags = 0;
	if (ccbiFlags & CCBI_REG_EXTENDED) flags |= REG_EXTENDED;
	if (ccbiFlags & CCBI_REG_ICASE)    flags |= REG_ICASE;
	if (ccbiFlags & CCBI_REG_NOSUB)    flags |= REG_NOSUB;
	if (ccbiFlags & CCBI_REG_NEWLINE)  flags |= REG_NEWLINE;

	switch (regcomp(&regex, pat, flags)) {
		case 0:            return 0;
		case REG_BADBR:    return CCBI_REG_BADBR;
		case REG_BADPAT:   return CCBI_REG_BADPAT;
		case REG_BADRPT:   return CCBI_REG_BADRPT;
		case REG_EBRACE:   return CCBI_REG_EBRACE;
		case REG_EBRACK:   return CCBI_REG_EBRACK;
		case REG_ECOLLATE: return CCBI_REG_ECOLLATE;
		case REG_ECTYPE:   return CCBI_REG_ECTYPE;
		case REG_EEND:     return CCBI_REG_EEND;
		case REG_EESCAPE:  return CCBI_REG_EESCAPE;
		case REG_EPAREN:   return CCBI_REG_EPAREN;
		case REG_ERANGE:   return CCBI_REG_ERANGE;
		case REG_ESIZE:    return CCBI_REG_ESIZE;
		case REG_ESPACE:   return CCBI_REG_ESPACE;
		case REG_ESUBREG:  return CCBI_REG_ESUBREG;
	}
	return -1; /* Impossible if POSIX-compliant implementation */
}

struct ccbi_regmatch_t* ccbi_execute(const char* str, uint8_t ccbiFlags) {

	size_t i;

	int flags = 0;
	if (ccbiFlags & CCBI_REG_NOTBOL) flags |= REG_NOTBOL;
	if (ccbiFlags & CCBI_REG_NOTEOL) flags |= REG_NOTEOL;

	if (regexec(&regex, str, MATCH_COUNT, matches.matches, flags))
		return NULL;

	if (sizeof(regoff_t) >= sizeof(ptrdiff_t)) {
		for (i = 0; i < MATCH_COUNT; i++) {
			/* Careful to load first lest we clobber the other field when storing
			 */
			regoff_t so = matches.matches[i].rm_so;
			regoff_t eo = matches.matches[i].rm_eo;
			matches.ccbi_matches[i].rm_so = so;
			matches.ccbi_matches[i].rm_eo = eo;
		}
	} else {
		/* This is only the case with POSIX-violating implementations, e.g.
		 * glibc: http://sourceware.org/bugzilla/show_bug.cgi?id=5945
		 */
		for (i = MATCH_COUNT; i--;) {
			regoff_t so = matches.matches[i].rm_so;
			regoff_t eo = matches.matches[i].rm_eo;
			matches.ccbi_matches[i].rm_so = so;
			matches.ccbi_matches[i].rm_eo = eo;
		}
	}
	return matches.ccbi_matches;
}

void ccbi_free() {
	regfree(&regex);
}
