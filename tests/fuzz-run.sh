#!/usr/bin/env bash
# Runs fuzz-batch.sh repeatedly until TARGET verdicts are collected, stopping early on any anomaly
# (sanitizer output, nonzero exit, accepted forgery). Each batch is capped by its own alarm (<= 5 min).
# Usage: tests/fuzz-run.sh <sanitizer_driver_bin> <out_dir> <target_total> [batch_start=0]
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
BIN="${1:?bin}"; OUT="${2:?out}"; TARGET="${3:?target}"; B0="${4:-0}"
SHARDS=10; PER=400; ALARM=280
per_batch=$(( SHARDS * PER ))
total=0; b=$B0
while [ "$total" -lt "$TARGET" ]; do
  line=$(bash "$HERE/fuzz-batch.sh" "$BIN" "$OUT" "$b" "$SHARDS" "$PER" "$ALARM" 2>&1); st=$?
  echo "$line"
  got=$(echo "$line" | sed -n 's/.*verdicts=\([0-9]*\).*/\1/p' | tail -1)
  acc=$(echo "$line" | sed -n 's/.*accepted_rc0=\([0-9]*\).*/\1/p' | tail -1)
  if [ "$st" -ne 0 ] || [ "${acc:-1}" -ne 0 ]; then echo "STOP: anomaly in batch $b (see lines above)"; exit 1; fi
  total=$(( total + got ))
  echo "cumulative verdicts=$total (target $TARGET)"
  b=$(( b + 1 ))
done
echo "DONE cumulative verdicts=$total batches=$(( b - B0 )) per_batch=$per_batch"
