// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:14:30

module ccbi.fingerprints.rcfunge98.iipc;

import ccbi.fingerprint;

// 0x49495043: IIPC
// Inter IP [sic] communicaiton [sic] extension
// --------------------------------------------

mixin (Fingerprint!(
	"IIPC",

	"A", "ancestorID",
	"D", "goDormant",
	"G", "popIP",
	"I", "ownID",
	"L", "topIP",
	"P", "pushIP"
));

template IIPC() {

// FungeMachine callback
bool executable(IP ip) {
	if (ip.mode & IP.DORMANT) {
		++stats.execDormant;
		return false;
	} else
		return true;
}

IP findIP(cell id) {
	// We could use a binary search if it weren't for TRDS
	foreach (ip; state.ips)
		if (ip.id == id)
			return ip;
	return null;
}

void ancestorID() {
	if (cip.id == cip.parentID)
		reverse();
	else
		cip.stack.push(cip.parentID);
}

void ownID() { cip.stack.push(cip.id); }
void goDormant() { ++stats.ipDormant; cip.mode |= cip.DORMANT; }

void topIP() {
	if (auto ip = findIP(cip.stack.pop))
		cip.stack.push(ip.stack.top);
}
void popIP() {
	if (auto ip = findIP(cip.stack.pop)) {
		cip.stack.push(ip.stack.pop);
		ip.mode &= ~cip.DORMANT;
	}
}
void pushIP() {
	auto id = cip.stack.pop,
	      c = cip.stack.pop;

	if (auto ip = findIP(id)) {
		ip.stack.push(c);
		ip.mode &= ~cip.DORMANT;
	}
}

}
