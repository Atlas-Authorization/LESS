#!/usr/bin/env bash
# run-cbmc-open.sh <Reference_Implementation dir> <TARGET: 192|68|45> [extra cbmc args]
# CBMC proof of crypto_sign_open memory safety (category 252). Run on a box with cbmc >= 6.
set -uo pipefail
REF="${1:?}"; TGT="${2:?}"; shift 2
HERE="$(cd "$(dirname "$0")" && pwd)"
OV="$(mktemp -d)/ref"; "$HERE/overlay.sh" "$REF" "$OV" >&2; REF="$OV"
L="$REF/lib"
cbmc "$HERE/harness_open.c" "$HERE/stubs_verify.c" "$L/sign.c" "$L/LESS.c" "$L/seedtree.c" "$L/monomial.c" "$L/rng.c" "$L/utils.c" \
  $( [ -f "$L/sort.c" ] && echo ) \
  -DCATEGORY=252 -DTARGET=$TGT -I "$REF/include" --function harness \
  --bounds-check --pointer-check --pointer-overflow-check --signed-overflow-check --unsigned-overflow-check \
  --conversion-check --undefined-shift-check --div-by-zero-check --pointer-primitive-check \
  --unwind 300 --unwinding-assertions --object-bits 16 "$@"
