/* dudect-style fixed-vs-random timing test of the individual LESS signing components that ctgrind flags
 * (secret-dependent branches / addresses), category 252, reference implementation. Cycle counter (rdtscp), one call per measurement,
 * classes interleaved at random, inputs prepared OUTSIDE the timed region. Pin with taskset.
 *   ct_comp <component> <N> <seed>      components: control prikey salt mulG rref blindcf cosetrep
 * class 0 = a FIXED secret (seed / ephemeral monomial seed / Q), class 1 = a fresh uniformly random one.
 * 'control' is a deliberately leaky early-exit compare: it MUST be detected, otherwise the harness is not trusted.
 * Output: Welch t on raw samples, on upper-tail-cropped samples (percentiles 50..99), and on centred-squared (second order). */
#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>
#include "parameters.h"
#include "rng.h"
#include "codes.h"
#include "monomial_mat.h"
#include "canonical.h"

static inline uint64_t cyc(void) { unsigned lo, hi; __asm__ volatile("lfence\n\trdtsc\n\tlfence" : "=a"(lo), "=d"(hi)::"memory"); return ((uint64_t)hi << 32) | lo; }
static uint64_t rs[2];
static uint64_t rnd64(void) { uint64_t s1 = rs[0], s0 = rs[1]; rs[0] = s0; s1 ^= s1 << 23; rs[1] = s1 ^ s0 ^ (s1 >> 18) ^ (s0 >> 5); return rs[1] + s0; }
static void fillr(uint8_t *p, size_t n) { for (size_t i = 0; i < n; i++) p[i] = (uint8_t)rnd64(); }

static uint8_t fixed_pseed[PRIVATE_KEY_SEED_LENGTH_BYTES], pseed[PRIVATE_KEY_SEED_LENGTH_BYTES];
static uint8_t fixed_eseed[SEED_LENGTH_BYTES], eseed[SEED_LENGTH_BYTES], salt[HASH_DIGEST_LENGTH];
static generator_mat_t full_G0, G0;
static monomial_t mono, Qm;
static uint8_t g0_flags[N_pad], permuted[N_pad], is_piv[N_pad], bits[N8];
static normalized_IS_t A;
static monomial_action_IS_t pi_tilde, mono_action;
static SHAKE_STATE_STRUCT cfstate;
static uint8_t ca[32], cb[32];

static void mk_G0(void) { /* ephemeral G0 * mu_tilde, the first thing LESS_sign does per round */
    monomial_sample_salt(&mono, eseed, salt, 0); generator_monomial_mul(&G0, &full_G0, &mono); }
static void mk_rref(void) { mk_G0(); memset(is_piv, 0, N_pad);
    for (uint32_t t = 0; t < N; t++) permuted[mono.permutation[t]] = g0_flags[t]; }

static void prep(const char *c, int cls) {
    if (!strcmp(c, "control")) { memset(ca, 7, 32); memcpy(cb, ca, 32); if (cls) cb[0] ^= 1; return; }
    if (cls) { fillr(pseed, sizeof pseed); fillr(eseed, sizeof eseed); } else { memcpy(pseed, fixed_pseed, sizeof pseed); memcpy(eseed, fixed_eseed, sizeof eseed); }
    if (!strcmp(c, "mulG")) { monomial_sample_salt(&mono, eseed, salt, 0); }
    else if (!strcmp(c, "rref")) { mk_rref(); }
    else if (!strcmp(c, "blindcf") || !strcmp(c, "cosetrep")) {
        mk_rref(); if (!generator_RREF_pivot_reuse_ct(&G0, is_piv, permuted, SIGN_PIVOT_REUSE_LIMIT)) { /* rare reduction failure: input is still a valid (if unreduced) matrix for timing purposes */ }
        normalized_copy_from_generator_non_information_set(&A, &G0, is_piv);
        monomial_compose_action_information_set(&pi_tilde, &mono, is_piv);
        uint8_t cs[SEED_LENGTH_BYTES]; fillr(cs, sizeof cs); initialize_csprng(&cfstate, cs, SEED_LENGTH_BYTES);
        if (!strcmp(c, "cosetrep")) { monomial_sample_prikey(&Qm, pseed); monomial_compose_action(&mono_action, &Qm, &pi_tilde); }
    }
}
/* Pool of pre-built inputs (building one costs ~6 ms: monomial mul + RREF), so class 1 draws from POOL random inputs and class 0 always
 * uses entry 0 (the fixed secret). Without the pool 10M samples would cost 17 h per component in preparation alone. */
#ifndef POOL
#define POOL 2048
#endif
typedef struct { generator_mat_t G0; uint8_t permuted[N_pad]; normalized_IS_t A; monomial_action_IS_t act; } Item;
static Item *pool;
static void build_item(const char *c, Item *it, int cls_random) {
    if (cls_random) { fillr(pseed, sizeof pseed); fillr(eseed, sizeof eseed); } else { memcpy(pseed, fixed_pseed, sizeof pseed); memcpy(eseed, fixed_eseed, sizeof eseed); }
    mk_rref(); it->G0 = G0; memcpy(it->permuted, permuted, N_pad);
    if (!strcmp(c, "blindcf") || !strcmp(c, "cosetrep")) {
        (void)generator_RREF_pivot_reuse_ct(&G0, is_piv, permuted, SIGN_PIVOT_REUSE_LIMIT);
        normalized_copy_from_generator_non_information_set(&A, &G0, is_piv); it->A = A;
        monomial_compose_action_information_set(&pi_tilde, &mono, is_piv);
        monomial_sample_prikey(&Qm, pseed); monomial_compose_action(&mono_action, &Qm, &pi_tilde); it->act = mono_action;
    }
}
static void prep_pooled(const char *c, int cls) {
    Item *it = &pool[cls ? 1 + (rnd64() % (POOL - 1)) : 0];
    if (!strcmp(c, "rref")) { G0 = it->G0; memcpy(permuted, it->permuted, N_pad); memset(is_piv, 0, N_pad); }
    else if (!strcmp(c, "blindcf")) { A = it->A; uint8_t cs[SEED_LENGTH_BYTES]; fillr(cs, sizeof cs); initialize_csprng(&cfstate, cs, SEED_LENGTH_BYTES); }
    else mono_action = it->act;
}
static volatile int sink;
static void run(const char *c) {
    if (!strcmp(c, "control")) { int i; for (i = 0; i < 32; i++) if (ca[i] != cb[i]) break; sink = i; }
    else if (!strcmp(c, "prikey")) monomial_sample_prikey(&mono, pseed);
    else if (!strcmp(c, "salt")) monomial_sample_salt(&mono, eseed, salt, 0);
    else if (!strcmp(c, "mulG")) generator_monomial_mul(&G0, &full_G0, &mono);
    else if (!strcmp(c, "rref")) sink = generator_RREF_pivot_reuse_ct(&G0, is_piv, permuted, SIGN_PIVOT_REUSE_LIMIT);
    else if (!strcmp(c, "blindcf")) { blind(&A, &cfstate); sink = CF(&A); }
    else if (!strcmp(c, "cosetrep")) CosetRep(bits, &mono_action);
}

typedef struct { double n, mean, m2; } Wf;
static void wpush(Wf *w, double x) { w->n += 1; double d = x - w->mean; w->mean += d / w->n; w->m2 += d * (x - w->mean); }
static double wt(const Wf *a, const Wf *b) { if (a->n < 2 || b->n < 2) return 0; double va = a->m2 / (a->n - 1), vb = b->m2 / (b->n - 1); double den = sqrt(va / a->n + vb / b->n); return den > 0 ? (a->mean - b->mean) / den : 0; }
static int cmpu(const void *a, const void *b) { uint32_t x = *(const uint32_t *)a, y = *(const uint32_t *)b; return (x > y) - (x < y); }

int main(int argc, char **argv) {
    if (argc < 4) { fprintf(stderr, "usage: ct_comp <component> <N> <seed>\n"); return 2; }
    const char *c = argv[1]; long NS = atol(argv[2]); rs[0] = 0x9E3779B97F4A7C15ull ^ (uint64_t)atoll(argv[3]); rs[1] = 0xD1B54A32D192ED03ull + (uint64_t)atoll(argv[3]) * 7919;
    for (int i = 0; i < 20; i++) rnd64();
    uint8_t s[48]; fillr(s, 48); initialize_csprng(&platform_csprng_state, s, 48);
    fillr(fixed_pseed, sizeof fixed_pseed); fillr(fixed_eseed, sizeof fixed_eseed); fillr(salt, sizeof salt);
    uint8_t g0seed[SEED_LENGTH_BYTES]; fillr(g0seed, sizeof g0seed);
    static rref_generator_mat_t G0r; generator_sample(&G0r, g0seed); generator_get_pivot_flags(&G0r, g0_flags); generator_rref_expand(&full_G0, &G0r);
    if (!strcmp(c, "rref") || !strcmp(c, "blindcf") || !strcmp(c, "cosetrep")) {
        pool = malloc(sizeof(Item) * POOL); for (int i = 0; i < POOL; i++) build_item(c, &pool[i], i != 0);
    }
    uint32_t *tm = malloc(sizeof(uint32_t) * NS); uint8_t *cls = malloc(NS);
    for (long i = 0; i < NS + 2000; i++) {
        int k = (int)(rnd64() >> 63); if (pool) prep_pooled(c, getenv("NULLTEST") ? 1 : k); else prep(c, getenv("NULLTEST") ? 1 : k); /* NULLTEST=1: both classes random (harness false-positive control) */
        uint64_t t0 = cyc(); run(c); uint64_t t1 = cyc();
        if (i >= 2000) { long j = i - 2000; cls[j] = (uint8_t)k; uint64_t d = t1 - t0; tm[j] = d > 0xFFFFFFFFu ? 0xFFFFFFFFu : (uint32_t)d; }
    }
    uint32_t *srt = malloc(sizeof(uint32_t) * NS); memcpy(srt, tm, sizeof(uint32_t) * NS); qsort(srt, NS, sizeof(uint32_t), cmpu);
    const double pc[] = {1.0, 0.99, 0.95, 0.90, 0.80, 0.70, 0.60, 0.50}; double best = 0; const char *bn = "raw";
    char bufn[64]; Wf m[2] = {{0}, {0}}; for (long i = 0; i < NS; i++) wpush(&m[cls[i]], tm[i]);
    printf("component=%s samples=%ld mean0=%.1f mean1=%.1f cycles\n", c, NS, m[0].mean, m[1].mean);
    for (unsigned q = 0; q < sizeof pc / sizeof *pc; q++) {
        uint32_t thr = srt[(long)((NS - 1) * pc[q])]; Wf w[2] = {{0}, {0}};
        for (long i = 0; i < NS; i++) if (tm[i] <= thr) wpush(&w[cls[i]], tm[i]);
        double t = wt(&w[0], &w[1]); printf("  crop<=p%.0f  t=%+.3f\n", pc[q] * 100, t);
        if (fabs(t) > fabs(best)) { best = t; snprintf(bufn, sizeof bufn, "crop p%.0f", pc[q] * 100); bn = bufn; }
    }
    Wf s2[2] = {{0}, {0}}; for (long i = 0; i < NS; i++) { double d = tm[i] - m[cls[i]].mean; wpush(&s2[cls[i]], d * d); }
    double t2 = wt(&s2[0], &s2[1]); printf("  second-order t=%+.3f\n", t2);
    if (fabs(t2) > fabs(best)) { best = t2; bn = "second-order"; }
    printf("RESULT component=%s N=%ld max|t|=%.3f (%s) %s\n", c, NS, fabs(best), bn, fabs(best) > 4.5 ? "LEAK-DETECTED(>4.5)" : "no-leak-detected(<=4.5)");
    return 0;
}
