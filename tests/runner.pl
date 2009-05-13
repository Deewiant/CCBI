#!/usr/bin/env perl

my $cmd = "bin/ccbi";
foreach $i (0 .. $#ARGV) {
	$cmd = "$cmd \"@ARGV[$i]\"";
}

my $input = @ARGV[$#ARGV];
if (-r "$input.in") {
	$cmd = "$cmd < $input.in";
}

exec $cmd or die "Couldn't exec '$cmd': $!\n";
