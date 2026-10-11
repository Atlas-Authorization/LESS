/* Compositional proof of the SampleChallenge contract (exactly W non-zero entries, each in [1, NUM_KEYPAIRS-1], memory safe) on the
 * REAL utils.c code, for every digest and every SHAKE output stream, UNBOUNDED in the number of rejection-sampling retries:
 *   sc_base : the real function up to the shuffle loop establishes the invariant IB (rejection loops by the invariant rule)
 *   sc_step : one real shuffle iteration preserves IB from any IB state (so IB holds after any number of iterations, i.e. at exit)
 *   sc_reach: control, must FAIL (shows the step's post-state is reachable, i.e. the assumptions are not vacuous) */
#include <stdint.h>
#include "parameters.h"
#include "sc_step.c"
void sc_base(void) { uint8_t digest[HASH_DIGEST_LENGTH]; uint8_t fws[T]; SampleChallenge_prefix(fws, digest); }
void sc_step(void) { uint8_t fws[T]; sc_shuffle_step(fws); }
void sc_frame(void) { uint8_t fws[T]; sc_shuffle_frame(fws); }
void sc_frame_reach(void) { uint8_t fws[T]; sc_shuffle_frame(fws); __CPROVER_assert(0, "reachability control (frame)"); }
void sc_reach(void) { uint8_t fws[T]; sc_shuffle_step(fws); __CPROVER_assert(0, "reachability control"); }
