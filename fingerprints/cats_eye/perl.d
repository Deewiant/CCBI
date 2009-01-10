// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File createD: 2007-01-20 21:06:53

module ccbi.fingerprints.cats_eye.perl; private:

import tango.core.Exception       : ProcessException;
import tango.io.Stdout            : Stdout;
import tango.sys.Process;
import tango.text.convert.Integer : parse;

import ccbi.cell;
import ccbi.fingerprint;
import ccbi.instructions : reverse;
import ccbi.ip;
import ccbi.utils;

// 0x4d4f4445: PERL
// Generic Interface to the Perl Language
// --------------------------------------

static this() {
	mixin (Code!("PERL"));

	fingerprints[PERL]['E'] =& eval!(false);
	fingerprints[PERL]['I'] =& eval!(true);
	fingerprints[PERL]['S'] =& shelled;
}

void shelled() { ip.stack.push(1); /+ this is not Perl, this is D +/ }

void eval(bool convertToInteger)() {
	auto program = popString();
	try {
		/+ The code below combines stderr and stdout for the Perl, so that we may
			pass it all through to our stdout.

		   This is done so that:
		   	- We can easily get to the eval return value - it's stderr.
		   	- The Perl program can nevertheless print on both stdout and stderr
		   	  (we don't eat either stream, we just combine them into stdout).

		   The code is in the $f subroutine so that it can't touch $real_stderr.

		   It can still do something like open($my_stderr, ">&2") though, and be
		   able to write to the real stderr, and we can't do anything about that.

		   Thanks to Heikki Kallasjoki for the Perl.
		+/
		const PERLCODE =
			`my $f = sub { eval($ARGV[0]) };
			open my $real_stderr, ">&STDERR";
			open STDERR, ">&STDOUT";
			print $real_stderr $f->();`;

		auto p = new Process("perl", "-e", PERLCODE, program);
		p.execute();
		p.stdin.detach();
		Stdout.copy(p.stdout);

		char[] string;
		char[80] buf = void;
		for (;;) {
			auto read = p.stderr.read(buf);
			if (read == p.stderr.Eof)
				break;
			else
				string ~= buf[0..read];
		}

		static if (convertToInteger) {
			static assert (
				cell.min >= typeof(parse("")).min && cell.max <= typeof(parse("")).max,
				"Change conversion in ccbi.fingerprints.cats_eye.perl.eval"
			);

			cell c = void;

			try c = cast(cell)parse(string);
			catch {
				c = -1;
			}
			ip.stack.push(c);
		} else
			pushStringz(string);

	} catch (ProcessException)
		return reverse();
}
