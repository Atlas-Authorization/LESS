#!/usr/bin/env bash
# run-cbmc-open.sh <Reference_Implementation dir> <TARGET> [cbmc args]
# crypto_sign_open memory safety for EVERY smlen (<= 2^40) and content, with LESS_verify stubbed by its memory precondition.
# For the unpatched positive control pass the unpatched tree: sign.c/monomial.c come from it, seedtree.c always from the patched
# tree because only that has CountPublishedSeeds (RebuildGGM is byte-identical in both).
# SC=real links the REAL SampleChallenge (utils.c, SHAKE stubbed) instead of the contract stub: discharges the assumption.
set -uo pipefail
REF="${1:?}"; TGT="${2:?}"; shift 2; PATCHED="${PATCHED_REF:-$REF}"
HERE="$(cd "$(dirname "$0")" && pwd)"
OV="$(mktemp -d)/ref"; "$HERE/overlay.sh" "$REF" "$OV" >&2
OP="$(mktemp -d)/ref"; "$HERE/overlay.sh" "$PATCHED" "$OP" >&2
cbmc "$HERE/harness_open.c" "$HERE/stubs_verify.c" "$HERE/stub_less_verify.c" "$OV/lib/sign.c" "$OP/lib/seedtree.c" "$OP/lib/rng.c" \
  -DCATEGORY=252 -DTARGET=$TGT -I "$OP/include" --function harness \
  --bounds-check --pointer-check --pointer-overflow-check --signed-overflow-check --unsigned-overflow-check \
  --conversion-check --undefined-shift-check --div-by-zero-check --pointer-primitive-check \
  --unwind 300 --unwinding-assertions --object-bits 16 "$@"
