#!/usr/bin/env bash
# Regenerates the official NIST KAT (CATEGORY=252 TARGET=45, 100 entries) with the upstream
# PQCgenKAT_sign harness against this repo's lib/ and compares byte-for-byte with the committed file.
# Needs OpenSSL (AES for the NIST DRBG). Usage: tests/kat-check.sh <work_dir>
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REF="$HERE/../Reference_Implementation"
W="${1:?usage: kat-check.sh <work_dir>}"; mkdir -p "$W"; W="$(cd "$W" && pwd)"
SSL="${OPENSSL_PREFIX:-$(brew --prefix openssl@3 2>/dev/null || echo /usr/local/opt/openssl@3)}"
SRCS=(codes.c fips202.c keccakf1600.c LESS.c monomial.c rng.c seedtree.c sign.c utils.c sort.c canonical.c transpose.c)
FILES=(); for s in "${SRCS[@]}"; do FILES+=("$REF/lib/$s"); done
cc -std=c99 -O2 -DCATEGORY=252 -DTARGET=45 -I "$REF/include" -I "$REF/lib/nist" -I "$SSL/include" \
   -Wno-unused-function -Wno-unused-parameter "${FILES[@]}" "$REF/lib/nist/KAT_NIST_rng.c" "$REF/lib/nist/PQCgenKAT_sign.c" \
   -L "$SSL/lib" -lcrypto -o "$W/kat_gen"
(cd "$W" && ./kat_gen > kat_stdout.txt 2>&1)
GOLD="$HERE/../Utilities/KAT_Generation/KAT"
cmp "$W/PQCsignKAT_97484.req" "$GOLD/PQCsignKAT_97484.req" && echo "REQ identical"
cmp "$W/PQCsignKAT_97484.rsp" "$GOLD/PQCsignKAT_97484.rsp" && echo "RSP identical ($(grep -c '^count' "$W/PQCsignKAT_97484.rsp") entries)"
