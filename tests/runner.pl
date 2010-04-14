#!/usr/bin/env perl

use Fcntl      'F_SETFD';
use File::Temp 'tempfile';
use Switch;

my $cmd = "bin/ccbi";
my $arg = @ARGV[$#ARGV];

$arg =~ /\.(.)98\.t$/ or die "Unknown test file extension!";

my $mode;
switch ($1) {
	case 'u' { $mode = '1' }
	case 'b' { $mode = '2' }
	case 't' { $mode = '3' }
}
if (! -e "tests/tmp/$mode") {
	print "1..0 # SKIP: -$mode not supported";
	exit;
}

$cmd = "$cmd -$mode \"$arg\"";

my $out; # Needs to be in scope of the exec
if (-r "$arg.in") {
	open my $in, '<', "$arg.in" or die "Couldn't read $arg.in: $!";

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
