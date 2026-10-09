#!/usr/bin/env bash
# Builds the reference verifier (lib/ of this repo, patched by the Atlas branch) plus
# tests/less_verify_driver.c natively, as an ASan+UBSan binary and an -O2 binary.
# Usage: tests/build-native.sh <out_dir>
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REF="$HERE/../Reference_Implementation"
OUT="${1:?usage: build-native.sh <out_dir>}"; mkdir -p "$OUT"
SRCS=(codes.c fips202.c keccakf1600.c LESS.c monomial.c rng.c seedtree.c sign.c utils.c sort.c canonical.c transpose.c)
FILES=(); for s in "${SRCS[@]}"; do FILES+=("$REF/lib/$s"); done
COMMON=(-std=c99 -DCATEGORY=252 -DTARGET=45 -I "$REF/include" -Wno-unused-function -Wno-unused-parameter -g)
cc "${COMMON[@]}" -O0 -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer \
   "${FILES[@]}" "$HERE/less_verify_driver.c" -o "$OUT/less_asan"
# -O2 with ASan+UBSan: sanitized AND ~20x faster than -O0 for the multi-thousand-input sweeps/fuzz
cc "${COMMON[@]}" -O2 -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer \
   "${FILES[@]}" "$HERE/less_verify_driver.c" -o "$OUT/less_san_O2"
cc "${COMMON[@]}" -O2 "${FILES[@]}" "$HERE/less_verify_driver.c" -o "$OUT/less_O2"
echo "built $OUT/less_asan $OUT/less_san_O2 $OUT/less_O2"
