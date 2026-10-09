#!/usr/bin/env bash
# One bounded structure-aware fuzz batch of crypto_sign_open under a sanitizer build.
# Runs SHARDS parallel shards, each generating PER_SHARD mutated signatures (fuzz-mutate.mjs) and verifying
# them in one driver process under a hard wall-clock alarm. A shard that does not finish is reported as
# INCOMPLETE, never as a pass. Pass criteria per batch: every shard exits 0, returns exactly PER_SHARD
# verdicts, stderr is empty (no sanitizer report), and accepted=0 (no mutated signature verifies).
# Usage: tests/fuzz-batch.sh <sanitizer_driver_bin> <out_dir> <batch_no> <shards> <per_shard> <alarm_s>
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
BIN="${1:?bin}"; OUT="${2:?out dir}"; BATCH="${3:?batch no}"; SHARDS="${4:?shards}"; PER="${5:?per shard}"; TMO="${6:?alarm s}"
mkdir -p "$OUT"
pids=()
for ((s=0; s<SHARDS; s++)); do
  seed=$(( BATCH * 1000 + s + 1 ))
  (
    node "$HERE/fuzz-mutate.mjs" "$BIN" "$PER" "$seed" "$OUT/b${BATCH}_s${s}.classes" 8 > "$OUT/b${BATCH}_s${s}.in" 2> "$OUT/b${BATCH}_s${s}.gen.err"
    perl -e 'alarm shift; exec @ARGV' "$TMO" "$BIN" open < "$OUT/b${BATCH}_s${s}.in" > "$OUT/b${BATCH}_s${s}.out" 2> "$OUT/b${BATCH}_s${s}.err"
    echo "$?" > "$OUT/b${BATCH}_s${s}.status"
  ) &
  pids+=($!)
done
wait
total=0; neg=0; acc=0; bad=0
for ((s=0; s<SHARDS; s++)); do
  f="$OUT/b${BATCH}_s${s}"
  st=$(cat "$f.status" 2>/dev/null || echo missing)
  n=$(awk 'NF' "$f.out" 2>/dev/null | wc -l | tr -d ' ')
  e=$(wc -c < "$f.err" 2>/dev/null | tr -d ' ')
  a=$(awk '$1=="0"' "$f.out" 2>/dev/null | wc -l | tr -d ' ')
  r=$(awk '$1=="-1"' "$f.out" 2>/dev/null | wc -l | tr -d ' ')
  total=$((total+n)); neg=$((neg+r)); acc=$((acc+a))
  if [ "$st" != 0 ] || [ "$n" -ne "$PER" ] || [ "$e" -ne 0 ] || [ "$a" -ne 0 ]; then bad=$((bad+1)); echo "shard $s: status=$st verdicts=$n/$PER stderr_bytes=$e accepted=$a (ANOMALY)"; fi
done
echo "batch $BATCH: shards=$SHARDS per_shard=$PER verdicts=$total rejected_rc-1=$neg accepted_rc0=$acc anomalous_shards=$bad"
[ "$bad" -eq 0 ] && [ "$total" -eq $(( SHARDS * PER )) ]
