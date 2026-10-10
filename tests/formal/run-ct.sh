#!/usr/bin/env bash
# run-ct.sh <Reference_Implementation dir> <TARGET> memcheck|memcheck-declass|dudect [N]   (Linux box with valgrind; dudect: pin with taskset)
#   memcheck          : whole sk marked undefined (over-approximate: also taints the PUBLIC derived values G_0_seed and the digest)
#   memcheck-declass  : same, but a patched COPY of LESS.c declassifies exactly the values that LESS publishes (G_0_seed, signature digest);
#                       every remaining report is a site where control flow / addresses depend on values that are secret at that point.
set -euo pipefail
REF="$1"; TGT="$2"; MODE="$3"; N="${4:-100000}"; HERE="$(cd "$(dirname "$0")" && pwd)"; O="$(mktemp -d)"
S=(codes.c fips202.c keccakf1600.c LESS.c monomial.c rng.c seedtree.c sign.c utils.c sort.c canonical.c transpose.c)
F=(); for s in "${S[@]}"; do F+=("$REF/lib/$s"); done
case "$MODE" in
memcheck|memcheck-declass)
  if [ "$MODE" = memcheck-declass ]; then
    cp "$REF/lib/LESS.c" "$O/LESS_declass.c"
    sed -i '1i #include <valgrind/memcheck.h>' "$O/LESS_declass.c"
    sed -i 's#^\(\s*csprng_randombytes(G_0_seed, SEED_LENGTH_BYTES, &sk_shake_state);\)#\1 VALGRIND_MAKE_MEM_DEFINED(G_0_seed, SEED_LENGTH_BYTES);#' "$O/LESS_declass.c"
    sed -i 's#^\(\s*LESS_SHA3_INC_FINALIZE(sig->digest, &state);\)#\1 VALGRIND_MAKE_MEM_DEFINED(sig->digest, HASH_DIGEST_LENGTH);#' "$O/LESS_declass.c"
    grep -c VALGRIND_MAKE_MEM_DEFINED "$O/LESS_declass.c" | grep -qx 2 || { echo "declassification patch did not apply"; exit 2; }
    F=(); for s in "${S[@]}"; do if [ "$s" = LESS.c ]; then F+=("$O/LESS_declass.c"); else F+=("$REF/lib/$s"); fi; done
  fi
  cc -std=gnu11 -O1 -g -DCATEGORY=252 -DTARGET=$TGT -DWITH_VALGRIND -I "$REF/include" "${F[@]}" "$HERE/ct_sign.c" -lm -o "$O/ct"
  valgrind --error-exitcode=0 --track-origins=yes --num-callers=10 "$O/ct" memcheck;;
dudect)
  cc -std=gnu11 -O2 -g -DCATEGORY=252 -DTARGET=$TGT -I "$REF/include" "${F[@]}" "$HERE/ct_sign.c" -lm -o "$O/ct"
  taskset -c 3 "$O/ct" dudect "$N";;
esac
