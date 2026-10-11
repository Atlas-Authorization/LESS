#!/usr/bin/env python3
"""overlay-sc.py <utils.c in> <utils.c out>: apply the loop-invariant rule BY HAND to the two rejection-sampling loops of SampleChallenge
(`do { BODY } while (COND);`, which retry until the PRNG stream yields an accepted value and therefore have no static bound):

    do { BODY } while (COND);        ==>      { c = nondet; assume(c <= 64);  rnd_buf = nondet;     // arbitrary state satisfying the invariant  c <= 64
                                                BODY                                                 // ONE iteration from that state: all memory/overflow checks of BODY apply
                                                assert(c <= 64);                                     // the invariant is preserved by an iteration (inductive step)
                                                assume(!(COND)); }                                   // loop exit state

Together with the base case (c = 0 at function entry, and c <= 64 after every earlier loop exit by the step assertion) this covers ANY number of
iterations (unbounded in the retry count) without unwinding. Everything the loop can change that the rest of the function reads is
c, rnd_buf, value|pos; the SHAKE state is only used through havoc'ing stubs. Termination is not claimed. Printed: the unified diff."""
import re, sys, difflib
src = open(sys.argv[1]).read()
start = src.index('void SampleChallenge(')
head, body = src[:start], src[start:]
head += 'uint32_t nondet_sc_u32(void);\nuint64_t nondet_sc_u64(void);\n\n'
assert len(re.findall(r'^\s*do \{\s*$', body, re.M)) == 2
body = re.sub(r'^(\s*)do \{\s*$', r'\1{ c = nondet_sc_u32(); __CPROVER_assume(c <= 64u); rnd_buf = nondet_sc_u64();', body, flags=re.M)
body, k = re.subn(r'^(\s*)\} while \((.*)\);\s*$', r'\1  __CPROVER_assert(c <= 64u, "rejection-loop invariant c <= 64 preserved"); __CPROVER_assume(!(\2)); }', body, flags=re.M)
assert k == 2, k
out = head + body
open(sys.argv[2], 'w').write(out)
for l in difflib.unified_diff(src.splitlines(), out.splitlines(), 'utils.c', 'utils.c(annotated)', lineterm='', n=0):
    if l[:1] in '+-' and l[:3] not in ('+++', '---'): print('overlay-sc:', l)
