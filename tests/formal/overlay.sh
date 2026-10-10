#!/usr/bin/env bash
# overlay.sh <Reference_Implementation dir> <out dir>
# Copies the reference sources and applies the ONLY transformation needed for CBMC's front-end:
#   fq_arith.h declares `static const EL_T SPAN = MAX_VALUE - MIN_VALUE;` etc. as function-local statics initialised from other
#   statics (accepted by gcc/clang as an extension, rejected by CBMC "expected constant expression"). `static const` -> `const`
#   gives the identical values. No other byte of the verified sources is changed (diff printed to stdout).
set -euo pipefail
REF="$1"; OUT="$2"; rm -rf "$OUT"; mkdir -p "$OUT"; cp -R "$REF/." "$OUT/"
sed -i.bak -E 's/static const (EL_T|size_t) (MIN_VALUE|MAX_VALUE|SPAN|REQ_BITS|EL_MASK)/const \1 \2/' "$OUT/include/fq_arith.h"
diff -u "$REF/include/fq_arith.h" "$OUT/include/fq_arith.h" | grep -E '^[-+][^-+]' | sed 's/^/overlay: /' || true
rm -f "$OUT/include/fq_arith.h.bak"
