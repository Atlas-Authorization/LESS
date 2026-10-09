#!/usr/bin/env bash
# Regression: each tests/regress/*.txt is one "<pkhex> <smhex>" line. Valid.txt must verify (rc 0);
# every other input must be rejected (rc -1) with no sanitizer report. Usage: tests/run-regress.sh <asan_bin>
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; BIN="${1:?usage: run-regress.sh <asan_bin>}"
fail=0
for f in "$HERE"/regress/*.txt; do
  name="$(basename "$f" .txt)"
  out="$("$BIN" open < "$f" 2>&1)"; st=$?
  rc="$(printf '%s' "$out" | awk 'NR==1{print $1}')"
  if [ "$st" -ne 0 ] || printf '%s' "$out" | grep -qE 'ERROR|runtime error|SUMMARY'; then echo "FAIL $name: exit=$st sanitizer output"; fail=1; continue; fi
  if [ "$name" = valid ]; then want=0; else want=-1; fi
  if [ "$rc" = "$want" ]; then echo "ok   $name rc=$rc"; else echo "FAIL $name rc=$rc want=$want"; fail=1; fi
done
exit $fail
