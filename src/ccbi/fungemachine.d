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

	static if (is(typeof(this.TRDS)))
		enum { GOT_TRDS = true  }
	else
		enum { GOT_TRDS = false }

	IP[] ips;
	IP   cip;
	IP   tip; // traced IP
	FungeSpace space;

	// For IPs
	cell currentID = 0;

	char[][] fungeArgs;

	// TRDS pretty much forces this to be signed (either that or handle signed
	// time displacements manually)
	long tick = 0;

	int returnVal;

	Flags flags;

	public this(File source, Flags f) {
		flags = f;

		static if (GOT_TRDS)
			alias TRDS.initialSpace firstSpace;
		else
			alias space firstSpace;

		firstSpace = new FungeSpace(source);

		ips.length = 1;
		reboot();
	}

	void reboot() {
		static if (GOT_TRDS) {
			if (flags.fingerprintsEnabled)
				space = new typeof(space)(initialSpace);
			else
				space = initialSpace;
		}

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
		static if (GOT_TRDS)
			bool normalTime = TRDS.isNormalTime();
		else
			const bool normalTime = true;

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

			static if (GOT_TRDS) {
				case Request.TIMEJUMP:
					TRDS.timeJump(cip);
					return true;
			}

				case Request.MOVE:
					cip.move();

				default: break;
			}

			Sout.flush;
			Serr.flush;
		}
		if (normalTime) {
			++tick;

			static if (GOT_TRDS)
				TRDS.newTick();
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

		if (flags.fingerprintsEnabled)
			static if (GOT_TRDS)
				TRDS.ipStopped(ip);

		ips.removeAt(idx);
		return ips.length > 0;
	}

	bool executable(bool normalTime, IP ip) {
		if (ips.length == 1)
			return true;

		static if (GOT_TRDS || is(typeof(this.IIPC))) {
			if (!flags.fingerprintsEnabled)
				return true;
		}

		static if (GOT_TRDS) {
			if (!TRDS.executable(normalTime, ip))
				return false;
		}
		static if (is(typeof(IIPC))) {
			if (!IIPC.executable(ip))
				return false;
		}
		return true;
	}

	void warn(char[] fmt, ...) {
		Serr.layout.convert(
			delegate uint(char[] s){ return Serr.write(s); },
			_arguments, _argptr, fmt);
	}
}
