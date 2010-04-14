#!/bin/sh

mkdir -p tests/tmp

# Parameters
for s in NEWBOX_PAD; do
	n=`grep "$s[[:space:]]*=" src/ccbi/space/space.d | sed -E 's/.*([0-9]+)[,;]/\1/'`
	if [ -z "$n" ]; then
		echo >&2 "$s not found in src/ccbi/space/space.d!"
		exit 1
	fi
	echo "$n" > tests/tmp/$s
done

# Supported geometries
for g in 1 2 3; do
	if ! `bin/ccbi -$g 2>&1 >/dev/null | grep -q 'unexpected argument'`; then
		touch tests/tmp/$g
	fi
done

prove -e tests/runner.pl -r tests $*

rm -r tests/tmp
