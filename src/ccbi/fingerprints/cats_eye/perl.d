// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:06:53

module ccbi.fingerprints.cats_eye.perl;

import ccbi.fingerprint;

mixin (Fingerprint!(
	"PERL",
	`Generic Interface to the Perl Language

      E and I push what eval() returned.

      Anything that the Perl program writes to stdout or stderr is captured and
      redirected to the Funge program's stdout. Trying to forcibly write to
      stderr from within the Perl (through tricks such as 'open($my_stderr,
      ">&2")') is deemed undefined behaviour and you do so at your own risk.`
      "\n",

	"E", "eval!(false)",
	"I", "eval!(true)",
	"S", "shelled"
));

template PERL() {

import tango.core.Exception       : ProcessException;
import tango.sys.Process;
import tango.text.convert.Integer : parse;

void shelled() { cip.stack.push(1); /+ this is not Perl, this is D +/ }

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
		Sout.copy(p.stdout);

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
				   cell.min >= typeof(parse("")).min
				&& cell.max <= typeof(parse("")).max,
				"Change conversion in ccbi.fingerprints.cats_eye.perl.eval"
			);

			cell c = void;

			try c = cast(cell)parse(string);
			catch {
				c = -1;
			}
			cip.stack.push(c);
		} else
			pushStringz(string);

	} catch (ProcessException)
		return reverse();
}

}
