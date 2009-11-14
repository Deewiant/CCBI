#!/bin/sh
ldc -singleobj -oq -Isrc -L-lncurses -O5 -release $* -of=bin/ccbi -od=obj src/ccbi/ccbi.d `ldmd -v -Isrc -o- -oq src/ccbi/ccbi.d | grep import | grep -v -e tango.core -e 'ldc\.' -e importall -e '\.di)' | perl -pe 's/import\s+[^\s]+\s+\((.+)\)/\1/' | fgrep -v template`
