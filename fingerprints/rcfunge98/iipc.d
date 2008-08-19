// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:14:30

module ccbi.fingerprints.rcfunge98.iipc; private:

import ccbi.fingerprint;
import ccbi.instructions : reverse;
import ccbi.ip;

// 0x49495043: IIPC
// Inter IP [sic] communicaiton [sic] extension
// --------------------------------------------

static this() {
	mixin (Code!("IIPC"));

	fingerprints[IIPC]['A'] =& ancestorID;
	fingerprints[IIPC]['D'] =& goDormant;
	fingerprints[IIPC]['G'] =& popIP;
	fingerprints[IIPC]['I'] =& ownID;
	fingerprints[IIPC]['L'] =& topIP;
	fingerprints[IIPC]['P'] =& pushIP;
}

void ancestorID() {
	if (ip.id == ip.parentID)
		reverse();
	else
		ip.stack.push(ip.parentID);
}

void ownID() { ip.stack.push(ip.id); }
void goDormant() { ip.mode |= IP.DORMANT; }

void topIP() {
	if (auto i = findIP(ip.stack.pop))
		ip.stack.push(i.stack.top);
}
void popIP() {
	if (auto i = findIP(ip.stack.pop)) {
		ip.stack.push(i.stack.pop);
		i.mode &= ~IP.DORMANT;
	}
}
void pushIP() {
	auto id = ip.stack.pop,
	      c = ip.stack.pop;

	if (auto i = findIP(id)) {
		i.stack.push(c);
		i.mode &= ~IP.DORMANT;
	}
}
