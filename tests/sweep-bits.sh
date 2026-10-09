#!/usr/bin/env bash
# Every-single-bit-flip sweep of one valid signature under the sanitizer build, sharded across N processes.
# Covers signature-relative bytes [START, END) (default: whole signature). Each shard must print a
# "done tried=... accepted=0" line, and must not print sanitizer output. Each shard runs under a hard
# timeout, so a run that does not finish is reported as incomplete, never as a pass.
# Usage: tests/sweep-bits.sh <asan_bin> <sweep_input_file> <out_dir> <shards> <timeout_s> [start] [end]
set -uo pipefail
BIN="$1"; IN="$2"; OUT="$3"; SHARDS="$4"; TMO="$5"
read -r PK SM MLEN <<< "$(cat "$IN")"
SIGLEN=$(( ${#SM} / 2 - MLEN ))
START="${6:-0}"; END="${7:-$SIGLEN}"
[ "$END" -gt "$SIGLEN" ] && END=$SIGLEN
mkdir -p "$OUT"; rm -f "$OUT"/shard_*.out "$OUT"/shard_*.err "$OUT"/shard_*.status
N=$(( END - START ))
PER=$(( (N + SHARDS - 1) / SHARDS ))
for ((s=0; s<SHARDS; s++)); do
  FROM=$(( START + s * PER )); TO=$(( FROM + PER )); [ "$TO" -gt "$END" ] && TO=$END
  [ "$FROM" -ge "$END" ] && break
  ( LESS_SWEEP_FROM=$FROM LESS_SWEEP_TO=$TO perl -e 'alarm shift; exec @ARGV' "$TMO" "$BIN" sweep < "$IN" > "$OUT/shard_$s.out" 2> "$OUT/shard_$s.err"; echo "exit=$? range=[$FROM,$TO)" > "$OUT/shard_$s.status" ) &
done
wait
