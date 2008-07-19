// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-06-08 12:03:42

module ccbi.fingerprints.rcfunge98.sock; private:

import tango.net.Socket;

import ccbi.fingerprint;
import ccbi.instructions : reverse;
import ccbi.ip;
import ccbi.space;
import ccbi.utils;

// 0x534f434b: SOCK
// tcp/ip [sic] socket extension
// -----------------------------

static this() {
	mixin (Code!("SOCK"));

	fingerprints[SOCK]['A'] =& accept;
	fingerprints[SOCK]['B'] =& bind;
	fingerprints[SOCK]['C'] =& connect;
	fingerprints[SOCK]['I'] =& toInt;
	fingerprints[SOCK]['K'] =& kill;
	fingerprints[SOCK]['L'] =& listen;
	fingerprints[SOCK]['O'] =& setOption;
	fingerprints[SOCK]['R'] =& receive;
	fingerprints[SOCK]['S'] =& create;
	fingerprints[SOCK]['W'] =& send;
}

Socket[] sockets;

AddressFamily popFam() {
	switch (ip.stack.pop) {
		case 1:  return AddressFamily.UNIX;
		case 2:  return AddressFamily.INET;
		default: return AddressFamily.UNSPEC;
	}
}

void create() {
	ProtocolType protocol;
	SocketType   type;

	with (ip.stack) {
		switch (pop) {
			case 1: protocol = ProtocolType.TCP; break;
			case 2: protocol = ProtocolType.UDP; break;
			default: return reverse();
		}

		switch (pop) {
			case 1: type = SocketType.DGRAM;  break;
			case 2: type = SocketType.STREAM; break;
			default: return reverse();
		}

		auto fam = popFam();
		if (fam == AddressFamily.UNSPEC)
			return reverse();

		try {
			auto s = sockets.length;
			foreach (i, sock; sockets)
			if (sock is null) {
				s = i;
				break;
			}

			auto sock = new Socket(fam, type, protocol);

			if (s == sockets.length)
				sockets.length = (sockets.length+1) * 2;
			sockets[s] = sock;

			push(cast(cell)s);
		} catch {
			reverse();
		}
	}
}

void kill() {
	auto s = cast(size_t)ip.stack.pop;

	if (s >= sockets.length || !sockets[s])
		return reverse();

	sockets[s].shutdown(SocketShutdown.BOTH);
	sockets[s].detach();
	delete sockets[s];

	if (s == sockets.length - 1)
		sockets.length = s;
}

void connect() {
	with (ip.stack) {
		auto address = cast(uint)  pop,
		     port    = cast(ushort)pop,
		     fam     = popFam(),
		     s       = cast(size_t)pop;

		if (fam == AddressFamily.UNSPEC || s >= sockets.length || !sockets[s])
			return reverse();

		try sockets[s].connect(new IPv4Address(address, port));
		catch {
			reverse();
		}
	}
}

void bind() {
	with (ip.stack) {
		auto address = cast(uint)  pop,
		     port    = cast(ushort)pop,
		     fam     = popFam(),
		     s       = cast(size_t)pop;

		if (fam == AddressFamily.UNSPEC || s >= sockets.length || !sockets[s])
			return reverse();

		try sockets[s].bind(new IPv4Address(address, port));
		catch {
			reverse();
		}
	}
}

void accept() {
	auto s = cast(size_t)ip.stack.pop;

	if (s >= sockets.length || !sockets[s])
		return reverse();

	try {
		sockets[s].accept(sockets[s]);

		auto a = cast(IPv4Address)sockets[s].remoteAddress;

		if (a)
			ip.stack.push(
				cast(cell)a.port,
				cast(cell)a.addr,
				cast(cell)s
			);
		else
			ip.stack.push(0, 0, cast(cell)s);
	} catch {
		reverse();
	}
}

ubyte[] buffer;

void receive() {
	with (ip.stack) {
		auto s   = cast(size_t)pop,
		     len = cast(size_t)pop;

		cellidx x, y;
		popVector(x, y);

		if (s >= sockets.length || !sockets[s])
			return reverse();

		if (len > buffer.length)
			buffer.length = len;

		auto got = sockets[s].receive(buffer);

		push(cast(cell)got);

		if (got == Socket.ERROR)
			return reverse();

		for (cellidx i = 0; i < cast(cellidx)got; ++i)
			space[x + i, y] = cast(cell)buffer[i];
	}
}

void send() {
	with (ip.stack) {
		auto s   = cast(size_t)pop,
		     len = cast(size_t)pop;

		cellidx x, y;
		popVector(x, y);

		if (s >= sockets.length || !sockets[s])
			return reverse();

		if (len > buffer.length)
			buffer.length = len;

		for (cellidx i = 0; i < cast(cellidx)len; ++i)
			buffer[i] = space[x + i, y];

		auto sent = sockets[s].send(buffer[0..len]);

		push(cast(cell)sent);

		if (sent == Socket.ERROR)
			return reverse();
	}
}

void listen() {
	auto s = cast(size_t)ip.stack.pop,
	     n = cast(int)   ip.stack.pop;

	if (s >= sockets.length || !sockets[s])
		return reverse();

	try sockets[s].listen(n);
	catch {
		return reverse();
	}
}

void setOption() {
	union Value {
		char[4] b;
		int[1] n;
	}
	Value val;

	auto s        = cast(size_t)ip.stack.pop,
	     t        =             ip.stack.pop;
	     val.n[0] = cast(int)   ip.stack.pop;

	if (s >= sockets.length || !sockets[s])
		return reverse();

	SocketOption o = void;

	switch (t) {
		case 1: o = SocketOption.SO_DEBUG;     break;
		case 2: o = SocketOption.SO_REUSEADDR; break;
		case 3: o = SocketOption.SO_KEEPALIVE; break;
		case 4: o = SocketOption.SO_DONTROUTE; break;
		case 5: o = SocketOption.SO_BROADCAST; break;
		case 6: o = SocketOption.SO_OOBINLINE; break;
		default: return reverse();
	}

	try sockets[s].setOption(SocketOptionLevel.SOCKET, o, val.b);
	catch {
		return reverse();
	}
}

void toInt() {
	auto n = IPv4Address.parse(cast(char[])popString());
	if (n == IPv4Address.ADDR_NONE)
		return reverse();
	else
		ip.stack.push(cast(cell)n);
}
