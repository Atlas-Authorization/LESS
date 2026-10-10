#!/usr/bin/env bash
# run-cbmc-unpack.sh <Reference_Implementation dir> <TARGET> [cbmc args]   (category 252)
set -uo pipefail
REF="${1:?}"; TGT="${2:?}"; shift 2
HERE="$(cd "$(dirname "$0")" && pwd)"
OV="$(mktemp -d)/ref"; "$HERE/overlay.sh" "$REF" "$OV" >&2; REF="$OV"
"$HERE/annotate-unpack.sh" "$REF"
cbmc "$HERE/harness_unpack.c" "$REF/lib/monomial_abs.c" -DCATEGORY=252 -DTARGET=$TGT -I "$REF/include" --function harness \
  --bounds-check --pointer-check --pointer-overflow-check --signed-overflow-check --unsigned-overflow-check \
  --conversion-check --undefined-shift-check --div-by-zero-check --unwind 300 --unwinding-assertions --object-bits 16 "$@"
