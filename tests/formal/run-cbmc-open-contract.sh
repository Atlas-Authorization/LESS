#!/usr/bin/env bash
# run-cbmc-open-contract.sh <Reference_Implementation dir> <TARGET> [cbmc args]
# crypto_sign_open memory safety for EVERY smlen (<= 2^40) and content, with every callee replaced by its PROVED contract:
#   SampleChallenge -> its contract (proved on the real code by harness_sc_contract.c), CountPublishedSeeds -> pure function (proved
#   safe and equal to RebuildGGM's read count by harness_rebuild_contract.c), LESS_verify -> its memory precondition (stub_less_verify.c),
#   hashing -> extent-checking stubs. No loop of crypto_sign_open is left except the constant T-iteration flag copy.
# For the unpatched positive control pass the unpatched tree (sign.c from it).
set -uo pipefail
REF="${1:?}"; TGT="${2:?}"; shift 2
HERE="$(cd "$(dirname "$0")" && pwd)"; PATCHED="${PATCHED_REF:-$REF}"
OV="$(mktemp -d)/ref"; "$HERE/overlay.sh" "$REF" "$OV" >&2
OP="$(mktemp -d)/ref"; "$HERE/overlay.sh" "$PATCHED" "$OP" >&2
cbmc "$HERE/harness_open.c" "$HERE/stubs_verify.c" "$HERE/stub_less_verify.c" "$HERE/stub_count_contract.c" "$OV/lib/sign.c" "$OP/lib/rng.c" \
  -DCATEGORY=252 -DTARGET=$TGT -I "$OP/include" --function harness \
  --bounds-check --pointer-check --pointer-overflow-check --signed-overflow-check --unsigned-overflow-check \
  --conversion-check --undefined-shift-check --div-by-zero-check --pointer-primitive-check \
  --unwind 300 --unwinding-assertions --object-bits 16 "$@"
