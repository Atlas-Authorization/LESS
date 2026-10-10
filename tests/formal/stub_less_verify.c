/* LESS_verify as an assume-guarantee STUB for the crypto_sign_open harness. It asserts the memory PRECONDITION that the real
 * LESS_verify (and RebuildGGM inside it) needs from its `sig` argument: the header (digest, salt, W canonical rows) and exactly
 * n = CountPublishedSeeds(challenge-derived flags) seeds are readable from sig. harness_verify.c / harness_rebuild.c discharge
 * the other direction (the real LESS_verify / RebuildGGM read no more than that). */
#include <stdint.h>
#include <stddef.h>
#include "parameters.h"
#include "LESS.h"
#include "seedtree.h"
#include "utils.h"
int nondet_int(void);
int LESS_verify(const pubkey_t *const PK, const char *const m, const size_t mlen, const sign_t *const sig) {
    (void)PK; (void)m; (void)mlen;
    uint8_t fws[T]; unsigned char flags[T];
    __CPROVER_assert(__CPROVER_r_ok(sig, offsetof(sign_t, seed_storage)), "LESS_verify precondition: header readable");
    SampleChallenge(fws, sig->digest);
    for (unsigned i = 0; i < T; i++) flags[i] = !!fws[i];
    uint32_t n = CountPublishedSeeds(flags);
    __CPROVER_assert(n <= MAX_PUBLISHED_SEEDS, "published seed count within the buffer type");
    __CPROVER_assert(__CPROVER_r_ok(sig, offsetof(sign_t, seed_storage) + (size_t)n * SEED_LENGTH_BYTES),
                     "LESS_verify precondition: all n seeds RebuildGGM will read lie inside the signature");
    return nondet_int() ? 1 : 0;   /* real LESS_verify returns 0 or 1 */
}
