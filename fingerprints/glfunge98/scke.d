// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:19:40

module ccbi.fingerprints.glfunge98.scke; private:

import tango.net.Socket;

import ccbi.fingerprint;
import ccbi.instructions : reverse;
import ccbi.ip;
import ccbi.utils;

import ccbi.fingerprints.rcfunge98.sock : sockets;

// 0x53434b45: SCKE
// ----------------

static this() {
	mixin (Code!("SCKE"));

	fingerprints[SCKE]['H'] =& getHostByName;
	fingerprints[SCKE]['P'] =& peek;
}

void getHostByName() {
	scope h = new NetHost;

	try if (!h.getHostByName(cast(char[])popString()))
		return reverse();
	catch {
		return reverse();
	}

	ip.stack.push(cast(cell)h.addrList[0]);
}

void peek() {
	auto s = cast(size_t)ip.stack.pop;

	if (s >= sockets.length || !sockets[s])
		return reverse();

	timeval t;
	t.tv_sec = t.tv_usec = 0;

	scope ss = new SocketSet(1);

	ss.add(sockets[s]);

	auto n = Socket.select(ss, null, null, &t);

	if (n == -1)
		reverse();
	else
		ip.stack.push(cast(cell)n);
}
