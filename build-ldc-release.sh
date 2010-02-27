#!/bin/sh
clang -O3 -c src/wrapncrs.c -o obj/wrapncrs.o || exit 1
ldc -singleobj -oq -Isrc -L-lncurses -O5 -release $* -of=bin/ccbi -od=obj obj/wrapncrs.o src/ccbi/ccbi.d `ldmd -v -Isrc -o- -oq src/ccbi/ccbi.d | grep import | grep -v -e tango.core -e 'ldc\.' -e importall -e '\.di)' | perl -pe 's/import\s+[^\s]+\s+\((.+)\)/\1/' | fgrep -v template`
