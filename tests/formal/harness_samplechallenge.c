/* CBMC harness: contract of the REAL SampleChallenge (utils.c) used as a stub in harness_open.c:
 * for every digest, the output has exactly W non-zero entries, each in [1, NUM_KEYPAIRS-1], and no memory error.
 * SHAKE is stubbed (squeeze havocs its output), i.e. the proof holds for ANY pseudo-random stream. */
#include <stdint.h>
#include "parameters.h"
void SampleChallenge_real(uint8_t fws[T], const uint8_t digest[HASH_DIGEST_LENGTH]);
void harness(void) {
    uint8_t digest[HASH_DIGEST_LENGTH];
    uint8_t fws[T];
    SampleChallenge_real(fws, digest);
    unsigned w = 0;
    for (unsigned i = 0; i < T; i++) {
        __CPROVER_assert(fws[i] <= NUM_KEYPAIRS - 1, "values in [0, NUM_KEYPAIRS-1]");
        w += (fws[i] != 0);
    }
    __CPROVER_assert(w == W, "exactly W non-zero entries");
}
