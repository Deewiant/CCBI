#!/bin/sh

n=`grep 'NEWBOX_PAD[[:space:]]*=' src/ccbi/space.d | sed -E 's/.*([0-9]+)[,;]/\1/'`
if [ -z $n ]; then
	echo "NEWBOX_PAD not found in src/ccbi/space.d!"
	exit 1
fi
ins=
for f in tests/space/*.t; do
	if [ ! -e "$f.in" ]; then
		echo $n > "$f.in"
		ins="$ins $f.in"
	fi
done

prove -e tests/runner.pl -r tests $*

rm $ins
