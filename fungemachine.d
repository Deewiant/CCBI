// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2008-08-16 17:48:28

module ccbi.fungemachine;

import tango.core.BitArray;
import tango.io.Buffer;
import tango.io.Print;
import tango.io.Stdout;
import tango.io.device.FileConduit;
import tango.io.stream.TypedStream;

import ccbi.container;
import ccbi.fingerprint;
import ccbi.ip;
import ccbi.request;
import ccbi.space;
import ccbi.stdlib;
import ccbi.templateutils;
import ccbi.tracer;
import ccbi.utils;
import ccbi.instructions.std;
import ccbi.instructions.templates;

// Essentially the only difference in Mini-Funge is the loading, since one has
// to deal with the =FOO commands
// 
// Other than that, have an executeMiniFunge to handle the differences

private TypedOutput!(ubyte) Cout;
private Print      !(char)  Sout, Serr;
static this() {
	Sout = new typeof(Sout)(
		Stdout.layout, new Buffer(new RawCoutFilter!(false), 32*1024));
	Serr = new typeof(Serr)(
		Stderr.layout, new Buffer(new RawCoutFilter!(true ), 32*1024));

	Cout = new typeof(Cout)(Sout.stream);
}
static ~this() {
	// Tango only flushes tango.io.Console.{Cout,Cerr}
	// we capture output before it gets that far
	Sout.flush;
	Serr.flush;
}

// The booleans must be in the same order wherever this is used: make it
// a mixin so that they're always the same
const booleans = `
mixin (Booleans!(
	"bools",
	"useStats",
	"script",
	"tracing",
	"fingerprintsEnabled",
	"warnings"
));`;

final class FungeMachine(cell dim) {
	static assert (dim >= 1 && dim <= 3);
private:
	alias .IP        !(dim)        IP;
	alias .FungeSpace!(dim)        FungeSpace;
	alias .Dimension !(dim).Coords InitCoords;

	// TODO: move all this TRDS stuff into TRDS template

	IP[] ips;
	IP   cip;
	IP   tip; // traced IP
	FungeSpace
		space,
		// for TRDS: keep a copy of the original space so we don't have to reload
		// from file
		initialSpace;

	char[][] fungeArgs;

	ulong
		tick = 0,
		// for TRDS: when rerunning time to jump point, don't output
		// (since that isn't "happening")
		printAfter = 0;

	// more TRDS stuff
	struct StoppedIPData {
		cell id;
		int jumpedAt, jumpedTo;
	}
	StoppedIPData[] stoppedIPdata;
	IP[] travellers;
	cell latestJumpTarget;
	IP timeStopper = null;

	int returnVal;

	mixin (booleans);

	public this(FileConduit source, BitArray ba) {
		bools = ba; // XXX: with MVRS, you might want to .dup here

		initialSpace = new FungeSpace(source);
		ips.length = 1;
		reboot();
	}

	// WORKAROUND: http://d.puremagic.com/issues/show_bug.cgi?id=2326
	final {
	void reboot() {
		if (fingerprintsEnabled)
			space = new typeof(space)(initialSpace);
		else
			space = initialSpace;

		tip = ips[0] = new IP(space);
		if (
			dim >= 2 &&
			script   &&
			space[InitCoords!(0,0)] == '#' &&
			space[InitCoords!(0,1)] == '!'
		)
			ips[0].pos.y = 1;
	}

	public int run() {
		try while (executeTick) {}
		catch (Exception e) {
			Sout.flush;
			Serr
				("Exited due to an error: ")(e.msg)
				(" at ")(e.file)(':')(e.line)
				.newline;
			returnVal = 1;
		}

		if (useStats) {
			Sout.flush;
//			printStats(Serr);
		}
		return returnVal;
	}

	bool executeTick() {
		bool normalTime = void; // TRDS

		if (fingerprintsEnabled) {
			normalTime = timeStopper is null;

			if (normalTime) {
				++tick;

				// If an IP is jumping to the future and it is the only one alive,
				// just jump.
				if (ips[0].jumpedTo > tick && ips.length == 1)
					tick = cip.jumpedTo;

				placeTimeTravellers();
			}
		} else
			++tick;

		if (tracing && !Tracer.doTrace())
			return false;

		for (auto j = ips.length; j-- > 0;)
		if (executable(normalTime, ips[j])) {

			cip = ips[j];
			cip.gotoNextInstruction();
			switch (executeInstruction()) {

				case Request.STOP:
					if (!stop(j)) {
				case Request.QUIT:
							return false;
					}
					break;

				case Request.TIMEJUMP:
					timeJump(cip);
					return true;

				case Request.MOVE:
					cip.move();

				default: break;
			}

			Sout.flush;
			Serr.flush;
		}
		return true;
	}
	}

	mixin .Tracer!() Tracer;

	// WORKAROUND: http://d.puremagic.com/issues/show_bug.cgi?id=2326
	final {
	Request executeInstruction() {
//		++stats.executionCount;

		auto c = space[cip.pos];

		if (c == '"')
			cip.mode ^= IP.STRING;
		else if (cip.mode & IP.STRING)
			cip.stack.push(c);
		else {
			if (fingerprintsEnabled) {
				// IMAP
				if (c >= 0 && c < cip.mapping.length) {
					c = cip.mapping[c];

					// Semantics are all in the range ['A','Z'], so since this
					// assert succeeds the isSemantics check can be inside this if
					// statement.
					static assert (cip.mapping.length > 'Z');

					if (isSemantics(c))
						return executeSemantics(c in cip.semantics);
				}
			}
			
			return executeStandard(c);
		}
		return Request.MOVE;
	}
	}

	mixin StdInstructions!() Std;
	mixin Utils!(dim);

	// WORKAROUND: http://d.puremagic.com/issues/show_bug.cgi?id=2326
final:

	Request executeStandard(cell c) {
		switch (c) mixin (Switch!(
			mixin (Ins!("Std",
				// WORKAROUND: http://d.puremagic.com/issues/show_bug.cgi?id=1059
				"!\"#$%&'()*+,-./0123456789:<=>?@\\_`abcdefgijknopqrstuxyz{" ~

//				Range!('!', ':') ~ Range!('<', '@') ~ "\\" ~ Range!('_', 'g') ~
//				Range!('i', 'k') ~ Range!('n', 'u') ~        Range!('x', '{') ~
				"}~" ~

				(dim >= 2 ? "[]^vw|" : "") ~
				(dim >= 3 ? "hlm"    : "")
			)),

			"default: unimplemented; break;"
		));
		return Request.MOVE;
	}

	Request executeSemantics(Stack!(Semantics)* sem) {
// TODO NEXT: compile in fingerprints similar to above
// so after template expansion we'd have here:
// if (type == BUILTIN) {
//    switch (sem.code) {
//        case 0xNULL: reverse;
//        case 0xSTRN: switch (c) { case 'S': printString; ... }
//		}
//	}
// etc.
// so Semantics just becomes bool+uint
// we need it for FNGR anyway


// TODO:		if (sem && sem.size) with (sem.top)
// TODO:			return type == BUILTIN ? instruction() : miniFunge();
		return unimplemented;
	}

	Request unimplemented() {
		if (warnings) {
			Sout.flush;
			// XXX: this looks like a hack
//			if (inMini)
//				miniUnimplemented();
/+			else +/ {
				auto i = space.unsafeGet(cip.pos);
				warn(
					"Unimplemented instruction '{}' ({1:d}) (0x{1:x})"
					" encountered at {}.",
					cast(char)i, i, cip.pos.toString
				);
			}
		}
		reverse;
		return Request.MOVE;
	}

	bool stop(size_t idx) {

		auto ip = ips[idx];

		Tracer.ipStopped(ip);

		if (fingerprintsEnabled) {
			// TODO: define TRDS.ipStopped
			// TRDS: resume time if the time stopper dies
			if (ip is timeStopper)
				timeStopper = null;

			// TRDS: store data of stopped IPs which have jumped
			// see ccbi.fingerprints.rcfunge98.trds.jump() for the reason
			if (ip.jumpedAt) {
				bool found = false;

				foreach (dat; stoppedIPdata)
					if (dat.id == ip.id && dat.jumpedAt == ip.jumpedAt) {
						found = true;
						break;
					}

				if (!found)
					stoppedIPdata ~=
						StoppedIPData(ip.id, ip.jumpedAt, ip.jumpedTo);
			}
		}

		ips.removeAt(idx);
		return ips.length > 0;
	}

	void timeJump(IP ip) {
		// nothing special if jumping to the future, just don't trace it
		if (tick != 0) {
			if (ip.jumpedTo >= ip.jumpedAt)
				ip.mode &= ~IP.FROM_FUTURE;

			if (ip is tip)
				tip = null;
			return;
		}

//		++stats.travelledToPast;

		// add ip to travellers unless it's already there
		bool found = false;
		foreach (traveller; travellers)
		if (traveller.id == ip.id && traveller.jumpedAt == ip.jumpedAt) {
			found = true;
			break;
		}
		if (!found) {
			ip.mode |= IP.FROM_FUTURE;
			travellers ~= new IP(ip);
		}

		latestJumpTarget = ip.jumpedTo;
		reboot();
	}

	void placeTimeTravellers() {
		for (size_t i = 0; i < travellers.length; ++i) {
			// if coming here, come here
			if (tick == travellers[i].jumpedTo)
				ips ~= travellers[i];

			/+
			Whenever we jump back in time, history from the jump target forward is
			forgotten. Thus if there are travellers that jumped to a time later
			than the jump target, forget about them as well.

			Example:
			- IP 1 travels from time 300 to 200.
			- We rerun from time 0 to 200, then place the IP. It does some stuff,
			  then teleports and jumps back to 300.

			- IP 2 travels from time 400 to 100.
			- We rerun from time 0 to 100, then place the IP. It does some stuff,
			  then teleports and jumps back to 400.

			- At time 300, IP 1 travels again to 200.
			- We rerun from time 0 to 200. But at time 100, we need to place IP 2
			  again. So we do. (Hence the whole travellers array.)
			- IP 2 does its stuff, and teleports and freezes itself until 400.

			- Come time 200, we would place IP 1 again if we hadn't done the
			  following, and removed it back when we placed IP 2 for the second
			  time.
			+/
			// TODO: remove these where we set latestJumpTarget so we don't need
			// the latestJumpTarget variable
			else if (latestJumpTarget < travellers[i].jumpedTo)
				travellers.removeAt(i--);
		}
	}

	bool executable(bool normalTime, IP ip) {
		return
			!fingerprintsEnabled || /+TODO verify this works ips.length == 1 ||+/ (
				(normalTime || timeStopper is ip) &&
				tick >= ip.jumpedTo &&
				!(ip.mode & ip.DORMANT)
			);
	}

	void warn(char[] fmt, ...) {
		Serr.layout.convert(
			delegate uint(char[] s){ return Serr.write(s); },
			_arguments, _argptr, fmt);
	}
}
