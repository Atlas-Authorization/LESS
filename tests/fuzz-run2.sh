#!/usr/bin/env bash
# Structure-aware fuzz campaign: runs fuzz-shard.sh for batches B0..B0+NB-1 (10 shards x PER each per batch),
# at most 4 shards concurrently. Stops at the first anomaly (sanitizer output, nonzero/alarm exit, incomplete
# shard, or any accepted forgery). Counts only verdicts that were actually returned.
# Usage: tests/fuzz-run2.sh <sanitizer_bin> <out_dir> <batch_start> <batches> <v1|v2> [per_shard=400] [alarm_s=900]
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
BIN="$1"; OUT="$2"; B0="$3"; NB="$4"; VER="$5"; PER="${6:-400}"; TMO="${7:-900}"; SHARDS=10
cum=0
for ((b=B0; b<B0+NB; b++)); do
  seq 0 $((SHARDS-1)) | xargs -P 4 -I{} bash "$HERE/fuzz-shard.sh" "$BIN" "$OUT" "$b" {} "$PER" "$TMO" "$VER"
  tot=0; acc=0; rej=0; bad=0
  for ((s=0; s<SHARDS; s++)); do
    read -r st n per e a r < "$OUT/b${b}_s${s}.summary" 2>/dev/null || { st=missing; n=0; per=$PER; e=-1; a=-1; r=0; }
    tot=$((tot+n)); acc=$((acc+a)); rej=$((rej+r))
    if [ "$st" != 0 ] || [ "$n" -ne "$PER" ] || [ "$e" -ne 0 ] || [ "$a" -ne 0 ]; then bad=$((bad+1)); echo "shard $s: status=$st verdicts=$n/$PER stderr_bytes=$e accepted=$a (ANOMALY)"; fi
  done
  cum=$((cum+tot))
  echo "batch $b ($VER): shards=$SHARDS verdicts=$tot rejected_rc-1=$rej accepted_rc0=$acc anomalous_shards=$bad cumulative_this_run=$cum"
  if [ "$bad" -ne 0 ] || [ "$acc" -ne 0 ]; then echo "STOP: anomaly in batch $b"; exit 1; fi
done
echo "DONE this_run_verdicts=$cum"
