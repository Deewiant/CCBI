#!/usr/bin/env perl

use Fcntl      'F_SETFD';
use File::Temp 'tempfile';
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
my $out; # Needs to be in scope of the exec
if (-r "$input.in") {
	open my $in, '<', "$input.in" or die "Couldn't read $input.in: $!";

	opendir my $dh, "tests/tmp" or die "Couldn't open tests/tmp: $!";
	%inRepls = grep !/^\./, readdir $dh;
	closedir $dh;

	$out = tempfile();

	while (<$in>) {
		chomp;
		if (exists $inRepls{$_}) {
			open my $fh, '<', "tests/tmp/$_"
				or die "Couldn't read tests/tmp/$_: $!";
			$_ = <$fh>;
			close $fh;
		}
		print $out $_;
	}
	close $in;

	fcntl($out, F_SETFD, 0)
		or die "Couldn't clear close-on-exec on temp file: $!";

	$cmd = "$cmd < /dev/fd/" . fileno $out;
}

exec $cmd or die "Couldn't exec '$cmd': $!";
