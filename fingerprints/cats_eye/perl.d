// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File createD: 2007-01-20 21:06:53

module ccbi.fingerprints.cats_eye.perl; private:

import tango.core.Exception       : ProcessException;
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
	auto s = cast(char[])popString();
	try {
		auto p = new Process("perl", "-e print 'A',eval(" ~ s ~ ")");
		p.execute();

		char[] string;
		char[80] buf;
		size_t read;
		for (;;) {
			read = p.stdout.input.read(buf);
			if (read != typeof(p.stdout).Eof)
				string ~= buf[0..read];
			else
				break;
		}

		// find the part of the string we care about, marked with the A
		size_t pos = string.length;

		foreach_reverse (i, c; string)
		if (c == 'A') {
			pos = i + 1;
			break;
		}

		assert (pos <= string.length);

		static if (convertToInteger) {
			static assert (
				cell.min >= typeof(parse("")).min && cell.max <= typeof(parse("")).max,
				"Change conversion in ccbi.fingerprints.cats_eye.perl.eval"
			);

			cell c = void;

			try  c = cast(cell)parse(string[pos..$]);
			catch {
				c = -1;
			}
			ip.stack.push(c);
		} else
			pushStringz(string[pos..$]);

	} catch (ProcessException e)
		return reverse();
}
