/* CBMC harness: for EVERY N8-byte row c (2^(8*N8) values, symbolic), if CheckCanonicalAction(c) accepts then the REAL
 * UnpackCosetRep is memory safe. This is the path of the upstream padding-bit defect (monomial.c:201).
 *
 * Counting lemmas (needed because the SAT problem "popcount == K  =>  every prefix has <= N-K zeros" is a pigeonhole-style
 * cardinality instance that CDCL does not solve): with S_i = number of ones among the first i coordinates and S_N = K
 * (proved from the accepted row),
 *     L1  S_i <= K                      (monotone: S_i <= S_{i+1} <= ... <= S_N)
 *     L2  S_i + (N - i) >= K            (S_N <= S_i + (N-i))
 * Each lemma is ASSERTED (proved by CBMC, in descending i so each step is a one-bit induction) and only then ASSUMED. */
#include <stdint.h>
#include "parameters.h"
#include "codes.h"
int CheckCanonicalAction(const uint8_t *b);
void harness(void) {
    uint8_t c[N8];   /* nondeterministic */
    static generator_mat_t res, G;
    uint8_t init[N], perm[N];
    if (CheckCanonicalAction(c)) {
        unsigned S[N + 1];
        S[0] = 0;
        for (unsigned i = 0; i < N; i++) S[i + 1] = S[i] + ((c[i / 8u] >> (i % 8u)) & 1u);
        __CPROVER_assert(S[N] == K, "CheckCanonicalAction => exactly K ones among the first N bits");
        __CPROVER_assume(S[N] == K);
        for (int i = N - 1; i >= 0; i--) {
            __CPROVER_assert(S[i] <= K, "L1");
            __CPROVER_assume(S[i] <= K);
            __CPROVER_assert(S[i] + (N - i) >= K, "L2");
            __CPROVER_assume(S[i] + (N - i) >= K);
        }
        UnpackCosetRep(&res, &G, c, init, perm);
    }
}
int main(void) { harness(); return 0; }
