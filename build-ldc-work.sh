#!/bin/sh
ldc -singleobj -Isrc -L-lncurses -L-ltango-user-ldc -O $* -of=bin/ccbi -od=obj src/ccbi/ccbi.d `ldmd -v -Isrc -o- src/ccbi/ccbi.d | grep import | grep -v tango | perl -pe 's/import\s+[^\s]+\s+\((.+)\)/\1/'`
