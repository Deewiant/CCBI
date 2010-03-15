// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2010-03-12 21:39:56

module ccbi.fingerprints.rcfunge98.rexp;

import ccbi.fingerprint;

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

	// Yay unspecified magic constants: must match the one in wraprexp.c!
	MATCH_COUNT = 256
};

extern (C) {
	ubyte            ccbi_compile(char*, ubyte);
	ccbi_regmatch_t* ccbi_execute(char*, ubyte);
	void             ccbi_free();
}
pragma(msg, "REXP :: remember to link with a POSIX-compatible regex library if necessary.");

struct ccbi_regmatch_t { ptrdiff_t rm_so, rm_eo; }

// 0x52455850: REXP
// Regular Expression Matching
// ---------------------------
mixin (Fingerprint!(
	"REXP",

	"C", "compile",
	"E", "execute",
	"F", "free"
));

template REXP() {

bool compiled = false, hadNoSub = false;

void compile() {
	auto flags = cast(ubyte)cip.stack.pop;
	auto pat   = popStringz();

	if (compiled)
		ccbi_free();

	auto failed = ccbi_compile(pat, flags);
	if (failed) {
		cip.stack.push(failed);
		reverse;
	} else
		hadNoSub = cast(bool)(flags & CCBI_REG_NOSUB);

	compiled = !failed;
}

import tango.stdc.string : strlen;
void execute() {
	if (!compiled)
		return reverse;

	auto flags = cast(ubyte)cip.stack.pop;
	auto str   = popStringz();

	auto matches = ccbi_execute(str, flags);
	if (!matches)
		return reverse;

	if (hadNoSub)
		return cip.stack.push(0);

	cell n = 0;
	for (auto i = MATCH_COUNT; i--;) if (matches[i].rm_so != -1) {
		++n;
		pushStringz(str[matches[i].rm_so .. matches[i].rm_eo]);
	}
	cip.stack.push(n);
}

void free() {
	if (compiled) {
		compiled = false;
		ccbi_free();
	}
}

}
