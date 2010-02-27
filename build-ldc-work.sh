#!/bin/sh
flags='-Isrc -d-debug -d-version=detectInfiniteLoops'
clang -O3 -c src/wrapncrs.c -o obj/wrapncrs.o || exit 1
ldc $flags -oq -singleobj -L-lncurses -L-ltango-user-ldc $* -of=bin/ccbi -od=obj obj/wrapncrs.o src/ccbi/ccbi.d `ldc $flags -v -oq -o- src/ccbi/ccbi.d | grep import | grep -v -e tango -e importall | perl -pe 's/import\s+[^\s]+\s+\((.+)\)/\1/' | fgrep -v template`
