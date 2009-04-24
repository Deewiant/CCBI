// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:19:40

module ccbi.fingerprints.glfunge98.scke; private:

import tango.net.Socket;
import tango.time.Time;

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

	if (!ss)
		ss = new SocketSet(1);
}

void getHostByName() {
	auto h = new NetHost;

	try if (!h.getHostByName(cast(char[])popString()))
		return reverse();
	catch {
		return reverse();
	}

	ip.stack.push(cast(cell)h.addrList[0]);
}

SocketSet ss;

void peek() {
	auto s = cast(size_t)ip.stack.pop;

	if (s >= sockets.length || !sockets[s])
		return reverse();

	ss.reset();
	ss.add(sockets[s]);

	auto n = Socket.select(ss, null, null, TimeSpan.zero);

	if (n == -1)
		reverse();
	else
		ip.stack.push(cast(cell)n);
}
