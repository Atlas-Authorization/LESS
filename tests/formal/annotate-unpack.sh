#!/usr/bin/env bash
# annotate-unpack.sh <ref dir>  -- writes <ref>/lib/monomial_abs.c: monomial.c in which the ONE inner column-copy loop of
# UnpackCosetRep
#       for (k = 0; k < K; k++) res->values[k][pos] = G->values[k][i*8 + j];
# is replaced by the bounds obligations of its body for all k < K (K <= K_pad rows):  pos < N_pad  and  i*8+j < N_pad.
# Reason: unrolling 252 columns x 126 rows of symbolic-index stores into a 31 KB array exhausts memory in CBMC, and the loop
# affects nothing but those two column indices. All other code of UnpackCosetRep (the control flow that computes pos from
# the bits of c) is unchanged and fully unwound. The abstraction is checked by assert, not assumed.
set -euo pipefail
python3 - "$1" <<'PY'
import sys
ref=sys.argv[1]; s=open(ref+'/lib/monomial.c').read()
pat='for (uint32_t k = 0; k < K; k++) {\n                res->values[k][pos] = G->values[k][i*8 + j];\n            }'
assert pat in s, 'column-copy loop not found'
s=s.replace(pat,'__CPROVER_assert(K <= K_pad, "rows"); __CPROVER_assert(pos < N_pad, "UnpackCosetRep: res column index in range"); __CPROVER_assert(i*8 + j < N_pad, "UnpackCosetRep: G column index in range");')
open(ref+'/lib/monomial_abs.c','w').write(s)
PY
