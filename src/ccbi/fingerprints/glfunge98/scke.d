// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:19:40

module ccbi.fingerprints.glfunge98.scke;

import ccbi.fingerprint;

// 0x53434b45: SCKE
// ----------------

mixin (Fingerprint!(
	"SCKE",

	"H", "getHostByName",
	"P", "peek"
));

template SCKE() {

alias SOCK.sockets sockets;

void ctor() {
	if (!ss)
		ss = new SocketSet(1);
}

SocketSet ss;

void getHostByName() {
	auto h = new NetHost;

	try if (!h.getHostByName(popString()))
		return reverse();
	catch {
		return reverse();
	}

	cip.stack.push(cast(cell)h.addrList[0]);
}

void peek() {
	auto s = cast(size_t)cip.stack.pop;

	if (s >= sockets.length || !sockets[s])
		return reverse();

	ss.reset();
	ss.add(sockets[s]);

	auto n = Socket.select(ss, null, null, TimeSpan.zero);

	if (n == -1)
		reverse();
	else
		cip.stack.push(cast(cell)n);
}

}