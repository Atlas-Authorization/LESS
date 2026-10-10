#!/usr/bin/env bash
# run-cbmc-samplechallenge.sh <Reference_Implementation dir> <TARGET> [cbmc args]
# Proves the contract of the REAL SampleChallenge (utils.c): on every digest and every pseudo-random stream (SHAKE havoced), if the function
# returns then exactly W entries are non-zero, each in [1, NUM_KEYPAIRS-1], with no memory/overflow error on any executed iteration.
# The two rejection-sampling loops (unbounded: they retry until the stream yields an accepted value) get a CBMC loop INVARIANT (c <= 64) and
# are abstracted by it (UNBOUNDED in the number of retries); all other loops have constant bounds and are fully unwound with unwinding
# assertions. Termination is NOT proved (it holds only with probability 1 over the stream; a worst-case stream could reject forever).
set -uo pipefail
REF="${1:?}"; TGT="${2:?}"; shift 2
HERE="$(cd "$(dirname "$0")" && pwd)"; W="$(mktemp -d)"
OV="$W/ref"; "$HERE/overlay.sh" "$REF" "$OV" >&2
python3 "$HERE/overlay-sc.py" "$OV/lib/utils.c" "$OV/lib/utils.c" >&2
printf '#define SampleChallenge SampleChallenge_real\n#include "%s/lib/utils.c"\n#undef SampleChallenge\n' "$OV" > "$W/utils_real.c"
printf 'void harness(void);\nint main(void){ harness(); return 0; }\n' > "$W/main.c"
CHK=(--bounds-check --pointer-check --pointer-overflow-check --signed-overflow-check --unsigned-overflow-check --conversion-check --undefined-shift-check --div-by-zero-check)
goto-cc -DCATEGORY=252 -DTARGET=$TGT -I "$OV/include" "$W/main.c" "$HERE/harness_samplechallenge.c" "$HERE/stubs_verify.c" "$W/utils_real.c" "$OV/lib/rng.c" -o "$W/sc.gb" || exit 2
goto-instrument --dfcc main --apply-loop-contracts "$W/sc.gb" "$W/sc2.gb" || exit 2
cbmc "$W/sc2.gb" "${CHK[@]}" --unwind 400 --unwinding-assertions --object-bits 16 "$@"
