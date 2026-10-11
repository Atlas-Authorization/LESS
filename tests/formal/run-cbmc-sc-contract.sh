#!/usr/bin/env bash
# run-cbmc-sc-contract.sh <Reference_Implementation dir> <TARGET> : base + step obligations (+ reachability control, expected FAILURE)
set -uo pipefail
REF="${1:?}"; TGT="${2:?}"; shift 2
HERE="$(cd "$(dirname "$0")" && pwd)"; W="$(mktemp -d)"; OV="$W/ref"; "$HERE/overlay.sh" "$REF" "$OV" >&2
python3 "$HERE/gen-sc-step.py" "$OV/lib/utils.c" "$W/sc_step.c" >&2
CHK=(--bounds-check --pointer-check --pointer-overflow-check --signed-overflow-check --unsigned-overflow-check --conversion-check --undefined-shift-check --div-by-zero-check)
for fn in ${FNS:-sc_base sc_step sc_reach}; do
  echo "=== $fn (TARGET $TGT)"
  cbmc "$HERE/harness_sc_contract.c" "$HERE/stubs_verify.c" "$OV/lib/rng.c" -I "$W" -I "$OV/lib" -I "$OV/include" -DREAL_SAMPLECHALLENGE -DCATEGORY=252 -DTARGET=$TGT \
     --function $fn "${CHK[@]}" --unwind 400 --unwinding-assertions --object-bits 16 "$@" 2>&1 | grep -a -E "FAILURE|^\*\* [0-9]+ of|^VERIFICATION|error"
done
