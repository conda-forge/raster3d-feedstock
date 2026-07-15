#!/usr/bin/env bash
set -exo pipefail

sed -i \
  -e 's|^prefix[[:space:]]*=[[:space:]]*/usr/local|prefix = '"${PREFIX}"'|' \
  -e 's|^INCDIRS[[:space:]]*=.*|INCDIRS  = -I'"${PREFIX}/include"'|' \
  -e 's|^LIBDIRS[[:space:]]*=.*|LIBDIRS  = -L'"${PREFIX}/lib"'|' \
  Makefile.template

make linux

sed -i \
  -e 's|OS = linux|OS = '$(uname | tr 'A-Z' 'a-z')'|g' \
  -e 's|CC = gcc|CC = '"${CC}"'|g' \
  -e 's|FC = gfortran|FC = '"${FC}"'|g' \
  Makefile.incl

make all -j${CPU_COUNT}
make install
