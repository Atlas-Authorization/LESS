#!/usr/bin/env python3
"""gen-sc-step.py <utils.c> <out.c> : compositional proof obligations for the REAL SampleChallenge (utils.c).

The function has (i) a zeroing loop and a value loop with CONSTANT indices, and (ii) a Fisher-Yates-style shuffle loop over p whose swap
position `pos` is symbolic (rejection-sampled). (ii) is what makes the monolithic CBMC run intractable. Both rejection loops
(`do { .. } while (C);`) are first rewritten by the loop-invariant rule of overlay-sc.py (invariant c <= 64; unbounded in retries).
Generated:
  SampleChallenge_prefix(fws, digest): the real function, with the shuffle loop replaced by  assert(IB(fws, c)); return;   [base case]
  sc_shuffle_step(fws, p, c, rnd_buf):  from ANY state with IB(fws, c) and T-W <= p < T, one VERBATIM shuffle iteration, then assert IB [step]
with IB(fws, c) := c <= 64  &&  exactly W entries non-zero  &&  every entry <= NUM_KEYPAIRS-1.
IB at loop exit (p == T) is exactly the contract. Termination of the rejection loops is not claimed."""
import re, sys, importlib.util, os
here = os.path.dirname(os.path.abspath(__file__))
src = open(sys.argv[1]).read()
start = src.index('void SampleChallenge(')
head, fn = src[:start], src[start:]
end = fn.index('\n}\n') + 3; fn, tail = fn[:end], fn[end:]
# loop-invariant rule on both rejection loops (same rewrite as overlay-sc.py)
assert len(re.findall(r'^\s*do \{\s*$', fn, re.M)) == 2
fn = re.sub(r'^(\s*)do \{\s*$', r'\1{ __CPROVER_assert(c <= 64u, "rejection-loop invariant holds on entry"); c = nondet_sc_u32(); __CPROVER_assume(c <= 64u); rnd_buf = nondet_sc_u64();', fn, flags=re.M)
fn, k = re.subn(r'^(\s*)\} while \((.*)\);\s*$', r'\1  __CPROVER_assert(c <= 64u, "rejection-loop invariant c <= 64 preserved"); __CPROVER_assume(!(\2)); }', fn, flags=re.M)
assert k == 2
hdr = 'for (uint32_t p = T - W; p < T; p++) {'
i = fn.index(hdr); j = i + len(hdr); depth, q = 1, j
while depth:
    depth += {'{': 1, '}': -1}.get(fn[q], 0); q += 1
body = fn[j:q - 1]
prefix = fn[:i] + '__CPROVER_assert(sc_IB(fixed_weight_string, c), "shuffle-loop invariant holds on entry"); return;' + fn[q:]
prefix = prefix.replace('void SampleChallenge(', 'void SampleChallenge_prefix(', 1)
out = head + '''uint32_t nondet_sc_u32(void);
uint64_t nondet_sc_u64(void);
static int sc_IB(const uint8_t fws[T], uint32_t c) {
    unsigned w = 0; int ok = (c <= 64u);
    for (unsigned k = 0; k < T; k++) { ok &= (fws[k] <= NUM_KEYPAIRS - 1); w += (fws[k] != 0); }
    return ok && w == W;
}
''' + prefix + '''
/* ONE iteration of the real shuffle loop, from an arbitrary invariant state */
void sc_shuffle_step(uint8_t fixed_weight_string[T]) {
    SHAKE_STATE_STRUCT shake_state;
    uint64_t rnd_buf = nondet_sc_u64(); uint32_t c = nondet_sc_u32(); uint32_t p = nondet_sc_u32();
    __CPROVER_assume(p >= T - W && p < T && sc_IB(fixed_weight_string, c));
    {''' + body + '''}
    __CPROVER_assert(sc_IB(fixed_weight_string, c), "shuffle-loop invariant preserved by one iteration");
}
/* FRAME form of the step (for the decomposed proof): from ANY array and any c <= 64, one verbatim iteration exchanges exactly the
 * entries at p and pos (pos <= p) and changes nothing else. Together with the transposition lemma (count and range are invariant under
 * exchanging two entries; tools/pca-implverif/verus/swap_count.rs) this gives the IB step without a global popcount in SAT. */
uint32_t nondet_sc_k(void);
void sc_shuffle_frame(uint8_t fixed_weight_string[T]) {
    SHAKE_STATE_STRUCT shake_state;
    uint64_t rnd_buf = nondet_sc_u64(); uint32_t c = nondet_sc_u32(); uint32_t p = nondet_sc_u32();
    __CPROVER_assume(p >= T - W && p < T && c <= 64u);
    uint8_t old[T]; for (unsigned k = 0; k < T; k++) old[k] = fixed_weight_string[k];
''' + body + '''
    __CPROVER_assert(pos <= p && c <= 64u, "frame: pos <= p, invariant on c");
    uint32_t k = nondet_sc_k(); __CPROVER_assume(k < T);
    __CPROVER_assert(fixed_weight_string[k] == (k == p ? old[pos] : (k == pos ? old[p] : old[k])), "frame: exactly entries p and pos exchanged");
}
''' + tail
open(sys.argv[2], 'w').write(out)
print('gen-sc-step: shuffle body', len(body), 'bytes')
