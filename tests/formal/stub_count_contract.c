/* CountPublishedSeeds replaced by its CONTRACT for the compositional crypto_sign_open proof:
 *   - it is a FUNCTION of indices_to_publish (pure: equal inputs give equal outputs; memoised here), with an arbitrary uint32 result;
 *   - it reads exactly T bytes of its argument and writes nothing visible.
 * Memory safety of the real CountPublishedSeeds for every input, and that its result equals the number of seeds RebuildGGM reads, are
 * proved separately (harness_rebuild_contract.c: link + base + step_count + step_rebuild). */
#include <stdint.h>
#include <string.h>
#include "parameters.h"
uint32_t nondet_cps(void);
static int cps_have; static unsigned char cps_in[T]; static uint32_t cps_out;
uint32_t CountPublishedSeeds(const unsigned char indices_to_publish[T]) {
    __CPROVER_assert(__CPROVER_r_ok(indices_to_publish, T), "CountPublishedSeeds reads T bytes");
    if (cps_have && memcmp(cps_in, indices_to_publish, T) == 0) return cps_out;
    uint32_t r = nondet_cps(); memcpy(cps_in, indices_to_publish, T); cps_out = r; cps_have = 1; return r;
}
