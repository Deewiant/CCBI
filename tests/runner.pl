#!/usr/bin/env perl

use Switch;

my $cmd = "bin/ccbi";
foreach $i (0 .. $#ARGV) {
	if (@ARGV[$i] =~ /\.(.)98\.t$/) {
		switch ($1) {
			case 'u' { $cmd = "$cmd -1" }
			case 'b' { $cmd = "$cmd -2" }
			case 't' { $cmd = "$cmd -3" }
		}
	}
	$cmd = "$cmd \"@ARGV[$i]\"";
}

my $input = @ARGV[$#ARGV];
if (-r "$input.in") {
	$cmd = "$cmd < $input.in";
}

exec $cmd or die "Couldn't exec '$cmd': $!\n";
