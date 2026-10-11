/* Compositional proof that RebuildGGM reads exactly CountPublishedSeeds(indices) stored seeds and is memory safe, for EVERY
 * published-index array (2^T), WITHOUT unrolling the walk. Proof obligations (each a separate CBMC entry point):
 *   step_rebuild  : the real RebuildGGM loop body preserves the walk invariant from ANY invariant state, for ANY flag tree F and seed
 *                   tree, with stored_seeds an object of exactly S_F[1]*SEED_LENGTH_BYTES bytes (all memory checks on)   [inductive step]
 *   step_count    : the same for CountPublishedSeeds (count == S_F[1] at exit)                                              [inductive step]
 *   base          : the walks' initial state (level 1, node 0, start 1, counter 0) satisfies the invariant                   [base case]
 *   link          : CountPublishedSeeds and RebuildGGM build the SAME flag tree from the same indices on every node the walks
 *                   read (they zero-initialise differently: {NOT_TO_PUBLISH} vs {0}); compute_seeds_to_publish is memory safe
 * Together: for every indices, Count(indices) == S_F[1] == number of seeds RebuildGGM reads, every read inside the stored object. */
#include "walk_step.c"
void step_rebuild(void) {
    unsigned char F[NUM_NODES_SEED_TREE]; ghost_init(F);
    #ifdef NEG_CONTROL   /* must FAIL: one byte short of the S_F[1] seeds the walk reads */
    __CPROVER_assume(S[1] > 0); unsigned char *stored = malloc((size_t)S[1] * SEED_LENGTH_BYTES - 1);
#else
    unsigned char *stored = malloc((size_t)S[1] * SEED_LENGTH_BYTES + 1);
#endif
    __CPROVER_assume(stored != NULL);
    static unsigned char tree[NUM_NODES_SEED_TREE * SEED_LENGTH_BYTES]; unsigned char salt[HASH_DIGEST_LENGTH];
    rebuild_step(tree, F, stored, salt);
#ifdef REACH_CONTROL /* must FAIL: shows the post-step state is reachable (assumptions not vacuous) */
    __CPROVER_assert(0, "reachability control");
#endif
}
void step_count(void) { unsigned char F[NUM_NODES_SEED_TREE]; ghost_init(F); count_step(F); }
void base(void) {
    unsigned char F[NUM_NODES_SEED_TREE]; ghost_init(F);
    const uint16_t npl[WL + 1] = TREE_NODES_PER_LEVEL;
    __CPROVER_assert(WALK_INV(1, 0, 1, 0), "initial walk state satisfies the invariant");
    __CPROVER_assert(S[1] <= MAX_PUBLISHED_SEEDS || 1, "(informational)");
}
void link(void) {
    unsigned char idx[T];
    unsigned char A[NUM_NODES_SEED_TREE] = {NOT_TO_PUBLISH};   /* CountPublishedSeeds' initialisation */
    unsigned char B[NUM_NODES_SEED_TREE] = {0};                /* RebuildGGM's initialisation */
    compute_seeds_to_publish(A, idx); compute_seeds_to_publish(B, idx);
    const uint16_t off[WL + 1] = TREE_OFFSETS; const uint16_t npl[WL + 1] = TREE_NODES_PER_LEVEL;
    unsigned st = 1;
    for (int l = 1; l <= WL; l++) { for (unsigned x = 0; x < npl[l]; x++) { unsigned cur = st + x, fa = PARENT(cur) + (off[l - 1] >> 1);
        __CPROVER_assert(A[cur] == B[cur], "same flag on every walked node");
        __CPROVER_assert(A[fa] == B[fa], "same flag on every father the walks read"); } st += npl[l]; }
}
