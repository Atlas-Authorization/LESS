#!/usr/bin/env bash
# Verifies every entry of an official NIST .rsp file (pk and sm fields) with the driver's raw
# crypto_sign_open (open mode, no Atlas guards beyond the patched library itself).
# Expects all entries to return rc 0 and the recorded mlen. Usage: tests/kat-verify.sh <driver_bin> <rsp_file>
set -uo pipefail
BIN="${1:?usage: kat-verify.sh <driver_bin> <rsp_file>}"; RSP="${2:?rsp file}"
IN="$(mktemp "${TMPDIR:-/tmp}/kat-open.XXXXXX")"
awk -F' = ' '
  $1=="mlen"  {ml=$2}
  $1=="pk"    {pk=$2}
  $1=="sm"    {print pk " " $2 " " ml; n++}
  END {print "entries " n > "/dev/stderr"}' "$RSP" > "$IN.pairs" 2> "$IN.n"
# driver open reads "<pk> <sm>" and prints "<rc> <mlen>"
awk '{print $1 " " $2}' "$IN.pairs" > "$IN"
"$BIN" open < "$IN" > "$IN.out" 2> "$IN.err"; st=$?
paste -d' ' "$IN.out" <(awk '{print $3}' "$IN.pairs") > "$IN.cmp"
ok=$(awk '$1==0 && $2==$3 {c++} END{print c+0}' "$IN.cmp")
total=$(wc -l < "$IN.pairs" | tr -d ' ')
echo "$(cat "$IN.n") driver_exit=$st verified_rc0_mlen_match=$ok/$total"
rm -f "$IN" "$IN.pairs" "$IN.n" "$IN.out" "$IN.err" "$IN.cmp"
[ "$st" -eq 0 ] && [ "$ok" -eq "$total" ] && [ "$total" -eq 100 ]
