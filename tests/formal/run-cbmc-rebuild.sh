#!/usr/bin/env bash
set -uo pipefail
REF="${1:?}"; TGT="${2:?}"; shift 2
HERE="$(cd "$(dirname "$0")" && pwd)"
OV="$(mktemp -d)/ref"; "$HERE/overlay.sh" "$REF" "$OV" >&2
cbmc "$HERE/harness_rebuild.c" "$HERE/stubs_verify.c" "$OV/lib/seedtree.c" "$OV/lib/rng.c" -DCATEGORY=252 -DTARGET=$TGT -I "$OV/include" --function harness \
  --bounds-check --pointer-check --pointer-overflow-check --signed-overflow-check --unsigned-overflow-check --conversion-check --undefined-shift-check --div-by-zero-check \
  --unwind 300 --unwinding-assertions --object-bits 16 "$@"
