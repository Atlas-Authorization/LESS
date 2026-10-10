#!/usr/bin/env bash
# One fuzz shard: generate PER mutated signatures (fuzz-mutate.mjs, mutator version VER) and verify them in
# ONE driver process under a generous hard alarm. Writes <out>/b<B>_s<S>.{classes,in,out,err,gen.err,status}.
# On a clean shard (status 0, PER verdicts, empty stderr, 0 accepted) the large .in file is deleted: it is
# regenerated bit-for-bit from the seed (BATCH*1000+S+1) and the mutator version.
# Usage: tests/fuzz-shard.sh <sanitizer_bin> <out_dir> <batch> <shard> <per_shard> <alarm_s> <v1|v2>
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
BIN="$1"; OUT="$2"; B="$3"; S="$4"; PER="$5"; TMO="$6"; VER="$7"
mkdir -p "$OUT"; f="$OUT/b${B}_s${S}"; seed=$(( B * 1000 + S + 1 ))
node "$HERE/fuzz-mutate.mjs" "$BIN" "$PER" "$seed" "$f.classes" 8 "$VER" > "$f.in" 2> "$f.gen.err"
perl -e 'alarm shift; exec @ARGV' "$TMO" "$BIN" open < "$f.in" > "$f.out" 2> "$f.err"
echo "$?" > "$f.status"
n=$(awk 'NF' "$f.out" | wc -l | tr -d ' '); e=$(wc -c < "$f.err" | tr -d ' '); a=$(awk '$1=="0"' "$f.out" | wc -l | tr -d ' '); r=$(awk '$1=="-1"' "$f.out" | wc -l | tr -d ' ')
st=$(cat "$f.status")
echo "$st $n $PER $e $a $r" > "$f.summary"
if [ "$st" = 0 ] && [ "$n" -eq "$PER" ] && [ "$e" -eq 0 ] && [ "$a" -eq 0 ]; then rm -f "$f.in"; fi
