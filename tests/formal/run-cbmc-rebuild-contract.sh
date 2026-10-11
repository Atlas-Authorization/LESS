#!/usr/bin/env bash
# run-cbmc-rebuild-contract.sh <Reference_Implementation dir> <TARGET> : runs the four proof obligations of harness_rebuild_contract.c
set -uo pipefail
REF="${1:?}"; TGT="${2:?}"; shift 2
HERE="$(cd "$(dirname "$0")" && pwd)"; W="$(mktemp -d)"; OV="$W/ref"; "$HERE/overlay.sh" "$REF" "$OV" >&2
python3 "$HERE/gen-walk-step.py" "$OV/lib/seedtree.c" "$W/walk_step.c" >&2
CHK=(--bounds-check --pointer-check --pointer-overflow-check --signed-overflow-check --unsigned-overflow-check --conversion-check --undefined-shift-check --div-by-zero-check)
rc=0
FNS="${FNS:-base link step_count step_rebuild}"
for fn in $FNS; do
  echo "=== $fn (TARGET $TGT)"
  cbmc "$HERE/harness_rebuild_contract.c" "$HERE/stubs_verify.c" "$OV/lib/rng.c" -I "$W" -I "$OV/lib" -I "$OV/include" -DCATEGORY=252 -DTARGET=$TGT \
     --function $fn "${CHK[@]}" --unwind 400 --unwinding-assertions --object-bits 16 "$@" 2>&1 | grep -a -E "FAILURE|^\*\* [0-9]+ of|^VERIFICATION|error" ; r=${PIPESTATUS[0]}; [ $r -ne 0 ] && rc=1
done
exit $rc
