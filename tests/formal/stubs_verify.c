/* CBMC assume-guarantee stubs for the LESS verifier proof harnesses (tests/formal).
 * Each stub (a) ASSERTS the exact memory extents the real callee reads, (b) HAVOCs exactly the extents it writes,
 * (c) returns nondeterministically. Memory safety of the stubbed callees themselves is NOT proved here (see
 * docs/pca/security/implementation-verification.md for which are proved separately and which are not). */
#include <stdint.h>
#include <string.h>
#include <stddef.h>
#include "parameters.h"
#include "codes.h"
#include "canonical.h"
#include "fips202.h"
#include "utils.h"

#define RD(p, n) __CPROVER_assert(__CPROVER_r_ok((p), (n)), "stub: callee read extent in bounds")
#define WR(p, n) __CPROVER_assert(__CPROVER_w_ok((p), (n)), "stub: callee write extent in bounds")
/* Callee outputs are not havoc-ed element-wise for big objects: CBMC treats uninitialised locals as nondeterministic and
 * no value in these matrices/hash states influences an index into the signature buffer; only the extent is checked.
 * Small outputs (seeds, flags) are havoc-ed so values read back are arbitrary. */
#define HAVOC(p, n) do { WR((p), (n)); if ((n) <= 64) __CPROVER_havoc_slice((void *)(p), (n)); } while (0)
int nondet_int(void);

/* ---- hashing (SHAKE128 for cat 252, SHA3-256 for the digest). Absorb READS its input; squeeze WRITES its output. ---- */
void shake128_inc_init(shake128incctx *s) { HAVOC(s, sizeof *s); }
void shake128_inc_absorb(shake128incctx *s, const uint8_t *in, size_t n) { RD(s, sizeof *s); RD(in, n); }
void shake128_inc_finalize(shake128incctx *s) { RD(s, sizeof *s); }
void shake128_inc_squeeze(uint8_t *out, size_t n, shake128incctx *s) { RD(s, sizeof *s); HAVOC(out, n); }
void sha3_256_inc_init(sha3_256incctx *s) { HAVOC(s, sizeof *s); }
void sha3_256_inc_absorb(sha3_256incctx *s, const uint8_t *in, size_t n) { RD(s, sizeof *s); RD(in, n); }
void sha3_256_inc_finalize(uint8_t *out, sha3_256incctx *s) { RD(s, sizeof *s); HAVOC(out, 32); }

/* ---- SampleChallenge: modelled as a FUNCTION of the digest (same digest => same output, since crypto_sign_open
 * and LESS_verify both call it on the same bytes) whose output has EXACTLY W non-zero entries, each in
 * [1, NUM_KEYPAIRS-1] (the contract of utils.c SampleChallenge; discharged separately in harness_samplechallenge.c). ---- */
static int sc_have;
static uint8_t sc_digest[HASH_DIGEST_LENGTH], sc_out[T];
void SampleChallenge(uint8_t fws[T], const uint8_t digest[HASH_DIGEST_LENGTH]) {
    RD(digest, HASH_DIGEST_LENGTH); WR(fws, T);
    if (sc_have && memcmp(sc_digest, digest, HASH_DIGEST_LENGTH) == 0) { memcpy(fws, sc_out, T); return; }
    uint8_t t[T];                 /* uninitialised => nondeterministic */
    unsigned w = 0;
    for (unsigned i = 0; i < T; i++) { __CPROVER_assume(t[i] <= NUM_KEYPAIRS - 1); w += (t[i] != 0); }
    __CPROVER_assume(w == W);
    memcpy(fws, t, T); memcpy(sc_out, t, T); memcpy(sc_digest, digest, HASH_DIGEST_LENGTH); sc_have = 1;
}

/* ---- matrix / code layer (signature-independent: operands are derived from the public key and seeds) ---- */
void generator_sample(rref_generator_mat_t *r, const unsigned char seed[SEED_LENGTH_BYTES]) { RD(seed, SEED_LENGTH_BYTES); HAVOC(r, sizeof *r); }
void generator_get_pivot_flags(const rref_generator_mat_t *G, uint8_t f[N]) { RD(G, sizeof *G); HAVOC(f, N); }
void generator_rref_expand(generator_mat_t *full, const rref_generator_mat_t *c) { RD(c, sizeof *c); HAVOC(full, sizeof *full); }
void expand_to_rref(generator_mat_t *full, const uint8_t *comp, uint8_t piv[N]) { RD(comp, RREF_MAT_PACKEDBYTES); HAVOC(full, sizeof *full); HAVOC(piv, N); }
void monomial_sample_salt(monomial_t *r, const unsigned char seed[SEED_LENGTH_BYTES], const unsigned char salt[HASH_DIGEST_LENGTH], uint16_t idx) {
    RD(seed, SEED_LENGTH_BYTES); RD(salt, HASH_DIGEST_LENGTH); HAVOC(r, sizeof *r); (void)idx; }
void generator_monomial_mul(generator_mat_t *res, const generator_mat_t *G, const monomial_t *m) { RD(G, sizeof *G); RD(m, sizeof *m); HAVOC(res, sizeof *res); }
int generator_RREF_pivot_reuse(generator_mat_t *G, uint8_t is_piv[N], uint8_t was[N], int limit) {
    (void)limit; WR(G, sizeof *G); RD(was, N); HAVOC(is_piv, N); return nondet_int(); }
int generator_RREF(generator_mat_t *G, uint8_t is_piv[N_pad]) { WR(G, sizeof *G); HAVOC(is_piv, N_pad); return nondet_int(); }
void normalized_copy_from_generator_non_information_set(normalized_IS_t *A, const generator_mat_t *G, const uint8_t *piv) {
    RD(G, sizeof *G); RD(piv, N_pad); HAVOC(A, sizeof *A); }
int CF(normalized_IS_t *A) { WR(A, sizeof *A); return nondet_int(); }

/* UnpackCosetRep: PRECONDITION asserted (proved sufficient for the real function in harness_unpack.c):
 * among the first N bits of c at most N-K are zero (i.e. at least K are one). Real CheckCanonicalAction must establish it. */
void UnpackCosetRep(generator_mat_t *res, const generator_mat_t *G, const uint8_t *c, const uint8_t init_piv[N], uint8_t perm_piv[N]) {
    RD(c, N8); RD(G, sizeof *G); RD(init_piv, N);
    unsigned ones = 0;
    for (unsigned i = 0; i < N; i++) ones += (c[i / 8u] >> (i % 8u)) & 1u;
    __CPROVER_assert(ones >= K, "UnpackCosetRep precondition: at most N-K zero coordinates (else write past N-sized arrays)");
    HAVOC(res, sizeof *res); HAVOC(perm_piv, N);
}
