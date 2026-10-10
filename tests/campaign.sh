#!/usr/bin/env bash
# Full evidence campaign (at most 4 concurrent sanitizer processes at any time):
#   1. all-bit sweeps of 3 valid signatures (message + signature bytes, every bit)
#   2. structure-aware fuzz batches (fuzz-run2.sh, mutator v2) continuing the v1 batches 0-5
#   3. exhaustive single-byte sweep (256 values x 128 positions) of signature A
# Usage: tests/campaign.sh <sanitizer_bin> <work_dir> <sweep_dir_with_sweep_{A,B,C}.in> <fuzz_batches>
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
BIN="$1"; W="$2"; SW="$3"; NB="$4"
mkdir -p "$W"
for T in A B C; do
  echo "== bit sweep $T start $(date)"
  bash "$HERE/sweep-bits.sh" "$BIN" "$SW/sweep_$T.in" "$W/bits_$T" 4 3600
  for f in "$W/bits_$T"/shard_*.out; do echo "bits_$T $(basename "$f") $(tail -1 "$f")"; done
  for f in "$W/bits_$T"/shard_*.status; do echo "bits_$T $(basename "$f") $(cat "$f")"; done
  cat "$W"/bits_$T/shard_*.err 2>/dev/null | wc -c | sed "s/^/bits_$T stderr_bytes=/"
done
echo "== fuzz start $(date)"
bash "$HERE/fuzz-run2.sh" "$BIN" "$W/fuzz" 6 "$NB" v2 400 900
echo "== fuzz end $(date)"
echo "== byte sweep start $(date)"
bash "$HERE/byte-sweep.sh" "$BIN" "$SW/sweep_A.in" "$W/bytes_A" 4 7200
echo "== campaign end $(date)"
