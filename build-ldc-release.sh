#!/bin/sh
fings='HRTI MODE MODU NULL ORTH PERL REFC ROMA TOYS TURT
       SCKE
       JSTR NCRS
       _3DSP BASE CPLI DATE DIRF EVAR FILE FIXP FPDP FPSP FRTH IIPC IMAP INDV SOCK STRN SUBR TERM TIME TRDS'

flags='-Isrc -oq -d-version=statistics'

for f in $fings; do flags="$flags -d-version=$f"; done

clang -O3 -c src/wrapncrs.c -o obj/wrapncrs.o || exit 1
ldc $flags -singleobj -L-lncurses -O5 -release $* -of=bin/ccbi -od=obj obj/wrapncrs.o src/ccbi/ccbi.d `ldc $flags -v -o- src/ccbi/ccbi.d | grep import | grep -v -e tango.core -e 'ldc\.' -e importall -e '\.di)' | perl -pe 's/import\s+[^\s]+\s+\((.+)\)/\1/' | fgrep -v template`
