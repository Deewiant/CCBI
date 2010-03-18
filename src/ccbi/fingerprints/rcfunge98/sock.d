// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2007-06-08 12:03:42

module ccbi.fingerprints.rcfunge98.sock;

import ccbi.fingerprint;

mixin (Fingerprint!(
	"SOCK",
	"tcp/ip [sic] socket extension",

	"A", "accept",
	"B", "bind",
	"C", "connect",
	"I", "toInt",
	"K", "kill",
	"L", "listen",
	"O", "setOption",
	"R", "receive",
	"S", "create",
	"W", "send"
));

template SOCK() {

import tango.net.device.Berkeley;

Berkeley*[] sockets;

AddressFamily popFam() {
	switch (cip.stack.pop) {
		case 1:  return AddressFamily.UNIX;
		case 2:  return AddressFamily.INET;
		default: return AddressFamily.UNSPEC;
	}
}

void create() {
	ProtocolType protocol;
	SocketType   type;

	with (*cip.stack) {
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

			auto sock = new Berkeley;
			sock.open(fam, type, protocol);

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
	auto s = cast(size_t)cip.stack.pop;

	if (s >= sockets.length || !sockets[s])
		return reverse();

	sockets[s].shutdown(SocketShutdown.BOTH);
	sockets[s].detach();
	sockets[s] = null;

	if (s == sockets.length - 1) {
		do --s;
		while (s < sockets.length && sockets[s] is null);
		sockets.length = s+1;
	}
}

void connect() {
	with (*cip.stack) {
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
	with (*cip.stack) {
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
	auto s = cast(size_t)cip.stack.pop;

	if (s >= sockets.length || !sockets[s])
		return reverse();

	try {
		auto as = new Berkeley;
		sockets[s].accept(*as);

		auto i = sockets.length;
		foreach (j, sock; sockets)
		if (sock is null) {
			i = j;
			break;
		}
		if (i == sockets.length)
			sockets.length = sockets.length * 2;
		sockets[i] = as;

		auto addr = cast(IPv4Address)as.remoteAddress;

		cip.stack.push(
			cast(cell)addr.port,
			cast(cell)addr.addr,
			cast(cell)i
		);
	} catch {
		reverse();
	}
}

ubyte[] buffer;

void receive() {
	with (*cip.stack) {
		auto s   = cast(size_t)pop,
		     len = cast(size_t)pop;

		Coords c = popOffsetVector();

		if (s >= sockets.length || !sockets[s])
			return reverse();

		if (len > buffer.length)
			buffer.length = len;

		auto got = sockets[s].receive(buffer);

		if (got == Berkeley.ERROR)
			return reverse();

		push(cast(cell)got);

		for (typeof(got) i = 0; i < got; ++i, ++c.x)
			state.space[c] = cast(cell)buffer[i];
	}
}

void send() {
	with (*cip.stack) {
		auto s   = cast(size_t)pop,
		     len = cast(size_t)pop;

		Coords c = popOffsetVector();

		if (s >= sockets.length || !sockets[s])
			return reverse();

		if (len > buffer.length)
			buffer.length = len;

		for (typeof(len) i = 0; i < len; ++i, ++c.x)
			buffer[i] = cast(ubyte)state.space[c];

		auto sent = sockets[s].send(buffer[0..len]);

		push(cast(cell)sent);

		if (sent == Berkeley.ERROR)
			return reverse();
	}
}

void listen() {
	auto s = cast(size_t)cip.stack.pop,
	     n = cast(int)   cip.stack.pop;

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

	auto s        = cast(size_t)cip.stack.pop,
	     t        =             cip.stack.pop;
	     val.n[0] = cast(int)   cip.stack.pop;

	if (s >= sockets.length || !sockets[s])
		return reverse();

	SocketOption o = void;

	switch (t) {
		case 1: o = SocketOption.DEBUG;     break;
		case 2: o = SocketOption.REUSEADDR; break;
		case 3: o = SocketOption.KEEPALIVE; break;
		case 4: o = SocketOption.DONTROUTE; break;
		case 5: o = SocketOption.BROADCAST; break;
		case 6: o = SocketOption.OOBINLINE; break;
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
		cip.stack.push(cast(cell)n);
}

}
