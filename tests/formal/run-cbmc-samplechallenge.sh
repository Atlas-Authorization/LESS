#!/usr/bin/env bash
# run-cbmc-samplechallenge.sh <Reference_Implementation dir> <TARGET> <retry-unwind> [cbmc args]
# Rejection-sampling loops cannot be fully unwound; they write only scratch state (rnd_buf, c, value, pos), never
# fixed_weight_string, so the exit-state property is checked with <retry-unwind> iterations and NO unwinding assertion on
# those loops (the documented, remaining assumption). All other loops are fully unwound (assertions on).
set -uo pipefail
REF="${1:?}"; TGT="${2:?}"; UW="${3:?}"; shift 3
HERE="$(cd "$(dirname "$0")" && pwd)"
OV="$(mktemp -d)/ref"; "$HERE/overlay.sh" "$REF" "$OV" >&2; REF="$OV"
W="$(mktemp -d)"; printf '#define SampleChallenge SampleChallenge_real\n#include "%s/lib/utils.c"\n' "$REF" > "$W/utils_real.c"
cbmc "$HERE/harness_samplechallenge.c" "$HERE/stubs_verify.c" "$W/utils_real.c" "$REF/lib/rng.c" -DCATEGORY=252 -DTARGET=$TGT -I "$REF/include" --function harness \
  --bounds-check --pointer-check --signed-overflow-check --unsigned-overflow-check --conversion-check --undefined-shift-check \
  --unwind "$UW" "$@"
