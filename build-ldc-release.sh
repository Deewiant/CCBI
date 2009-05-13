#!/bin/sh
ldc -singleobj -Isrc -L-lncurses -O5 -release $* -of=bin/ccbi -od=obj src/ccbi/ccbi.d `ldmd -v -Isrc -o- src/ccbi/ccbi.d | grep import | grep -vE 'tango.core|tango.ldc|di\)' | perl -pe 's/import\s+[^\s]+\s+\((.+)\)/\1/'`
