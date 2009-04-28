// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2008-08-16 17:48:28

module ccbi.fungemachine;

import tango.io.Stdout;
import tango.io.device.File     : File;
import tango.io.stream.Buffered : BufferedOutput;
import tango.io.stream.Format;
import tango.io.stream.Typed;

import ccbi.container;
import ccbi.fingerprint;
import ccbi.flags;
import ccbi.ip;
import ccbi.request;
import ccbi.space;
import ccbi.stdlib;
import ccbi.templateutils;
import ccbi.tracer;
import ccbi.utils;
import ccbi.fingerprints.all;
import ccbi.instructions.std;
import ccbi.instructions.templates;

mixin (InsImports!());

// Essentially the only difference in Mini-Funge is the loading, since one has
// to deal with the =FOO commands
//
// Other than that, have an executeMiniFunge to handle the differences

private  TypedOutput!(ubyte) Cout;
private FormatOutput!(char)  Sout, Serr;
static this() {
	Sout = new typeof(Sout)(
		Stdout.layout, new BufferedOutput(new RawCoutFilter!(false), 32*1024));
	Serr = new typeof(Serr)(
		Stderr.layout, new BufferedOutput(new RawCoutFilter!(true ), 32*1024));

	Cout = new typeof(Cout)(Sout.stream);
}
static ~this() {
	// Tango only flushes tango.io.Console.{Cout,Cerr}
	// we capture output before it gets that far
	Sout.flush;
	Serr.flush;
}

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

	// For IPs
	cell currentID = 0;

	char[][] fungeArgs;

	// TRDS pretty much forces this to be signed (either that or handle signed
	// time displacements manually)
	long
		tick = 0,
		// for TRDS: when rerunning time to jump point, don't output
		// (since that isn't "happening")
		printAfter = 0;

	// more TRDS stuff
	struct StoppedIPData {
		typeof(cip.id) id;
		typeof(tick) jumpedAt, jumpedTo;
	}
	StoppedIPData[] stoppedIPdata;
	IP[] travellers;
	IP timeStopper = null;

	int returnVal;

	Flags flags;

	public this(File source, Flags f) {
		flags = f;

		initialSpace = new FungeSpace(source);
		ips.length = 1;
		reboot();
	}

	void reboot() {
		if (flags.fingerprintsEnabled)
			space = new typeof(space)(initialSpace);
		else
			space = initialSpace;

		tip = ips[0] = new IP(space);
		if (
			dim >= 2     &&
			flags.script &&
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

		if (flags.useStats) {
			Sout.flush;
//			printStats(Serr);
		}
		return returnVal;
	}

	bool executeTick() {
		bool normalTime = timeStopper is null; // TRDS

		if (flags.tracing && !Tracer.doTrace())
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
		if (normalTime) {
			++tick;

			if (flags.fingerprintsEnabled) {
				// If an IP is jumping to the future and it is the only one alive,
				// just jump.
				if (ips[0].jumpedTo > tick && ips.length == 1)
					tick = ips[0].jumpedTo;

				placeTimeTravellers();
			}
		}
		return true;
	}

	mixin .Tracer!() Tracer;

	Request executeInstruction() {
//		++stats.executionCount;

		auto c = space[cip.pos];

		if (c == '"')
			cip.mode ^= IP.STRING;
		else if (cip.mode & IP.STRING)
			cip.stack.push(c);
		else {
			if (flags.fingerprintsEnabled) {
				// IMAP
				if (c >= 0 && c < cip.mapping.length) {
					c = cip.mapping[c];

					// Semantics are all in the range ['A','Z'], so since this
					// assert succeeds the isSemantics check can be inside this if
					// statement.
					static assert (cip.mapping.length > 'Z');

					if (isSemantics(c))
						return executeSemantics(c);
				}
			}

			return executeStandard(c);
		}
		return Request.MOVE;
	}

	mixin StdInstructions!() Std;
	mixin Utils!();

// TODO: move dim information to instructions themselves, since fingerprints
// need it as well
	Request executeStandard(cell c) {
		switch (c) mixin (Switch!(
			Ins!("Std",
				// WORKAROUND: http://d.puremagic.com/issues/show_bug.cgi?id=1059
				"!\"#$%&'()*+,-./0123456789:<=>?@\\_`abcdefgijknopqrstuxyz{" ~

//				Range!('!', ':') ~ Range!('<', '@') ~ "\\" ~ Range!('_', 'g') ~
//				Range!('i', 'k') ~ Range!('n', 'u') ~        Range!('x', '{') ~
				"}~" ~

				(dim >= 2 ? "[]^vw|" : "") ~
				(dim >= 3 ? "hlm"    : "")
			),

			"default: unimplemented; break;"
		));
		return Request.MOVE;
	}

	mixin (ConcatMapTuple!(TemplateMixin,    ALL_FINGERPRINTS));
	mixin (ConcatMapTuple!(FingerprintCount, ALL_FINGERPRINTS));

	void loadedFingerprint(cell fingerprint) {
		switch (fingerprint) mixin (Switch!(
			FingerprintConstructorCases!(ALL_FINGERPRINTS),
			"default: break;"
		));
	}
	void unloadedFingerprintIns(cell fingerprint) {
		switch (fingerprint) mixin (Switch!(
			FingerprintDestructorCases!(ALL_FINGERPRINTS),
			"default: break;"
		));
	}

	Request executeSemantics(cell c)
	in {
		assert (isSemantics(c));
	} body {
		auto stack = cip.semantics[c - 'A'];
		if (stack.empty)
			return unimplemented;

		auto sem = stack.top;

		switch (sem.fingerprint) mixin (Switch!(
			// foreach fing, generates the following:
			// case HexCode!(fing):
			// 	switch (sem.instruction) mixin (Switch!(
			// 		mixin (Ins!(fing, Range!('A', 'Z'))),
			// 		"default: assert (false);"
			// 	));

			FingerprintExecutionCases!(
				"sem.instruction",
				"assert (false);",
				ALL_FINGERPRINTS),
			"default: unimplemented; break;"
		));

		return Request.MOVE;
	}

	Request unimplemented() {
		if (flags.warnings) {
			Sout.flush;
			// XXX: this looks like a hack
//			if (inMini)
//				miniUnimplemented();
/+			else +/ {
				auto i = space[cip.pos];
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

		if (flags.fingerprintsEnabled) {
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
					stoppedIPdata ~= StoppedIPData(ip.id, ip.jumpedAt, ip.jumpedTo);
			}
		}

		ips.removeAt(idx);
		return ips.length > 0;
	}

	void timeJump(IP ip) {
		// nothing special if jumping to the future, just don't trace it
		if (tick > 0) {
			if (ip.jumpedTo >= ip.jumpedAt)
				ip.mode &= ~IP.FROM_FUTURE;

			// TODO: move this to Tracer
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

		/+
		Whenever we jump back in time, history from the jump target forward is
		forgotten. Thus if there are travellers that jumped to a time later than
		the jump target, forget about them as well.

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
		  following, and removed it back when we placed IP 2 for the second time.
		+/
		for (size_t i = 0; i < travellers.length; ++i)
			if (ip.jumpedTo < travellers[i].jumpedTo)
				travellers.removeAt(i--);

		reboot();
	}

	void placeTimeTravellers() {
		// Must be appended: preserves correct execution order
		for (size_t i = 0; i < travellers.length; ++i)
			if (tick == travellers[i].jumpedTo)
				ips ~= new IP(travellers[i]);
	}

	bool executable(bool normalTime, IP ip) {
		return
			ips.length == 1 || (
				flags.fingerprintsEnabled &&
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
