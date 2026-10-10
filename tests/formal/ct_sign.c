/* Side-channel checks of the LESS signing path (secret key -> signature), reference implementation, category 252.
 *   ct_sign memcheck   : ctgrind. SK bytes are marked UNDEFINED for valgrind memcheck; any conditional jump / address
 *                        computed from them is reported as "Conditional jump or move depends on uninitialised value(s)".
 *   ct_sign dudect <N> : dudect-style Welch t-test on LESS_sign wall time, class 0 = fixed secret key,
 *                        class 1 = fresh random secret key per call, random class order, 5% upper-tail cropping, N total samples.
 * This is a TEST, not a proof: absence of a significant t statistic bounds only what this harness can resolve. */
#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <math.h>
#include "api.h"
#include "rng.h"
#include "LESS.h"
#ifdef WITH_VALGRIND
#include <valgrind/memcheck.h>
#endif

static void seed_rng(uint8_t s) { unsigned char seed[48]; memset(seed, s, sizeof seed); initialize_csprng(&platform_csprng_state, seed, sizeof seed); }
static int cmp(const void *a, const void *b) { double x = *(double *)a, y = *(double *)b; return (x > y) - (x < y); }
static uint64_t now_ns(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC_RAW, &t); return (uint64_t)t.tv_sec * 1000000000ull + t.tv_nsec; }

typedef struct { double n, mean, m2; } Wf;
static void wpush(Wf *w, double x) { w->n += 1; double d = x - w->mean; w->mean += d / w->n; w->m2 += d * (x - w->mean); }
static double wt(const Wf *a, const Wf *b) { double va = a->m2 / (a->n - 1), vb = b->m2 / (b->n - 1); return (a->mean - b->mean) / sqrt(va / a->n + vb / b->n); }

int main(int argc, char **argv) {
    static pubkey_t pk; static prikey_t sk, skfix; static sign_t sig;
    const char msg[] = "ct-test-message";
    if (argc > 1 && !strcmp(argv[1], "memcheck")) {
#ifdef WITH_VALGRIND
        seed_rng(1); LESS_keygen(&sk, &pk);
        seed_rng(2);                                  /* public randomness (salt) */
        VALGRIND_MAKE_MEM_UNDEFINED(&sk, sizeof sk);  /* the secret */
        size_t r = LESS_sign(&sk, msg, sizeof msg, &sig);
        VALGRIND_MAKE_MEM_DEFINED(&r, sizeof r);
        fprintf(stderr, "sign done, opened=%zu\n", r);
#else
        fprintf(stderr, "built without valgrind\n");
#endif
        return 0;
    }
    long NS = (argc > 2) ? atol(argv[2]) : 100000;
    int sd = (argc > 3) ? atoi(argv[3]) : 0, nullt = (argc > 4) && !strcmp(argv[4], "null");   /* null: BOTH classes use fresh random keys */
    seed_rng(7 + sd); LESS_keygen(&skfix, &pk);
    static double *tm; static unsigned char *cls; tm = malloc(sizeof(double) * NS); cls = malloc(NS);
    srand(9 + sd); seed_rng(9 + sd);
    for (long i = 0; i < NS; i++) {
        cls[i] = rand() & 1;
        if (cls[i] || nullt) { static pubkey_t p2; LESS_keygen(&sk, &p2); } else sk = skfix;   /* keygen is outside the timed region */
        uint64_t t0 = now_ns();
        (void)LESS_sign(&sk, msg, sizeof msg, &sig);
        tm[i] = (double)(now_ns() - t0);
        if ((i & 1023) == 1023) { fprintf(stderr, "progress %ld/%ld\n", i + 1, NS); }
    }
    double *srt = malloc(sizeof(double) * NS); memcpy(srt, tm, sizeof(double) * NS);
    qsort(srt, NS, sizeof(double), cmp);
    const double pc[] = {1.0, 0.99, 0.95, 0.90, 0.80, 0.70, 0.60, 0.50}; double best = 0; Wf all[2] = {{0}, {0}};
    for (long i = 0; i < NS; i++) wpush(&all[cls[i]], tm[i]);
    printf("samples=%ld mode=%s fixed_mean=%.0fns random_mean=%.0fns\n", NS, nullt ? "NULL(random-vs-random)" : "fixed-vs-random", all[0].mean, all[1].mean);
    for (unsigned q = 0; q < sizeof pc / sizeof *pc; q++) {
        double thr = srt[(long)((NS - 1) * pc[q])]; Wf w[2] = {{0}, {0}};
        for (long i = 0; i < NS; i++) if (tm[i] <= thr) wpush(&w[cls[i]], tm[i]);
        double t = wt(&w[0], &w[1]); printf("  crop<=p%.0f t=%+.3f\n", pc[q] * 100, t); if (fabs(t) > fabs(best)) best = t;
    }
    Wf s2[2] = {{0}, {0}}; for (long i = 0; i < NS; i++) { double d = tm[i] - all[cls[i]].mean; wpush(&s2[cls[i]], d * d); }
    double t2 = wt(&s2[0], &s2[1]); printf("  second-order t=%+.3f\n", t2); if (fabs(t2) > fabs(best)) best = t2;
    printf("RESULT sign N=%ld max|t|=%.3f %s\n", NS, fabs(best), fabs(best) > 4.5 ? "LEAK-DETECTED(>4.5)" : "no-leak-detected(<=4.5)");
    return 0;
}
