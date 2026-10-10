/* CBMC: RebuildGGM memory safety for EVERY published-index array (2^T) when `stored` holds exactly CountPublishedSeeds(flags) seeds. */
#include <stdlib.h>
#include <stdint.h>
#include "parameters.h"
#include "seedtree.h"
void harness(void) {
    unsigned char flags[T];                      /* nondet 0/1 per leaf */
    for (unsigned i = 0; i < T; i++) __CPROVER_assume(flags[i] <= 1);
    uint32_t n = CountPublishedSeeds(flags);
    __CPROVER_assume(n <= MAX_PUBLISHED_SEEDS);
    unsigned char *stored = malloc((size_t)n * SEED_LENGTH_BYTES + 1);   /* exactly the bytes the signature carries (+1 so n=0 is a valid object) */
    unsigned char salt[HASH_DIGEST_LENGTH];
    static unsigned char tree[NUM_NODES_SEED_TREE * SEED_LENGTH_BYTES];
    __CPROVER_assume(stored);
    (void)RebuildGGM(tree, flags, stored, salt);
}
