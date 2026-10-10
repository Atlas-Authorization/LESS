#!/usr/bin/env bash
# Exhaustive single-byte sweep: for the 128 positions (64-byte header + last 64 bytes of the signed message)
# and all 256 values each (32768 verifications), sharded over SHARDS concurrent driver processes, each under a
# generous alarm. Per position, exactly one verdict must be rc 0 (the original byte value, which is the valid
# signature) and it must equal the original byte; every other value must be rejected with no sanitizer output.
# Usage: tests/byte-sweep.sh <sanitizer_bin> <input "pk sm mlen"> <out_dir> <shards> <alarm_s>
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
BIN="$1"; IN="$2"; OUT="$3"; SHARDS="$4"; TMO="$5"
read -r PK SM MLEN < "$IN"
[ "${MLEN:-0}" -gt 0 ] || { echo "byte-sweep: input must carry the true message length (not 0)" >&2; exit 2; }
mkdir -p "$OUT"; rm -f "$OUT"/bs_*.out "$OUT"/bs_*.err "$OUT"/bs_*.status
NP=128; PER=$(( (NP + SHARDS - 1) / SHARDS ))
for ((s=0; s<SHARDS; s++)); do
  A=$(( s * PER )); E=$(( A + PER )); [ "$E" -gt "$NP" ] && E=$NP
  ( node "$HERE/byte-sweep.mjs" "$IN" "$A" "$E" 2> "$OUT/bs_$s.origs" | perl -e 'alarm shift; exec @ARGV' "$TMO" "$BIN" open > "$OUT/bs_$s.out" 2> "$OUT/bs_$s.err"; echo "$? $A $E" > "$OUT/bs_$s.status" ) &
done
wait
ok=0; bad=0
for ((s=0; s<SHARDS; s++)); do read -r st A E < "$OUT/bs_$s.status" 2>/dev/null || { st=missing; A=0; E=0; }
  n=$(awk 'NF' "$OUT/bs_$s.out" | wc -l | tr -d ' '); e=$(wc -c < "$OUT/bs_$s.err" | tr -d ' ')
  want=$(( (E - A) * 256 ))
  if [ "$st" != 0 ] || [ "$n" -ne "$want" ] || [ "$e" -ne 0 ]; then echo "shard $s: status=$st verdicts=$n/$want stderr_bytes=$e (ANOMALY)"; bad=$((bad+1)); fi
  # per position: count rc0 and check it is the original byte value
  awk -v A="$A" -v E="$E" 'FNR==NR{ if($1=="P") orig[$2]=$4; next }
       NF{k=FNR-1; pi=A+int(k/256); v=k%256; if($1==0){ c[pi]++; if(v!=orig[pi]) wrong[pi]++ } else if($1!=-1) other++ }
       END{ for(p=A;p<E;p++){ if(c[p]!=1 || wrong[p]) {print "pos " p " rc0_count=" c[p]+0 " rc0_not_original=" wrong[p]+0; bad_p++} } ; print "shard " A ".." E " rc0_checked_per_position=1 other_rc=" other+0 " bad_positions=" bad_p+0 }' "$OUT/bs_$s.origs" "$OUT/bs_$s.out"
done
echo "byte-sweep shards=$SHARDS anomalous=$bad"
[ "$bad" -eq 0 ]
