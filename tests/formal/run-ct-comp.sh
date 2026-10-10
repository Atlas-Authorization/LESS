#!/usr/bin/env bash
# run-ct-comp.sh <Reference_Implementation dir> <TARGET> <outdir> : builds ct_comp (-O2) and prints the build line
set -euo pipefail
REF="$1"; TGT="$2"; OUT="$3"; HERE="$(cd "$(dirname "$0")" && pwd)"; mkdir -p "$OUT"
S=(codes.c fips202.c keccakf1600.c LESS.c monomial.c rng.c seedtree.c sign.c utils.c sort.c canonical.c transpose.c); F=(); for s in "${S[@]}"; do F+=("$REF/lib/$s"); done
cc -std=gnu11 -O2 -g -DCATEGORY=252 -DTARGET=$TGT -I "$REF/include" "${F[@]}" "$HERE/ct_comp.c" -lm -o "$OUT/ct_comp"
echo built "$OUT/ct_comp"
