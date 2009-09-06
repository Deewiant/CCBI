#!/bin/sh
flags='-Isrc -d-debug -d-version=detectInfiniteLoops'
ldc $flags -oq -singleobj -L-lncurses -L-ltango-user-ldc -O $* -of=bin/ccbi -od=obj src/ccbi/ccbi.d `ldc $flags -v -oq -o- src/ccbi/ccbi.d | grep import | grep -v tango | perl -pe 's/import\s+[^\s]+\s+\((.+)\)/\1/' | fgrep -v template`
