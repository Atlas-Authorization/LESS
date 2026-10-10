#!/usr/bin/env python3
"""overlay-sc.py <utils.c in> <utils.c out>: annotate the two rejection-sampling loops of SampleChallenge with a CBMC loop invariant.
CBMC's contract syntax is not accepted on do-while, so each `do { B } while (C);` of those two loops is rewritten to the equivalent
`while (1) __CPROVER_loop_invariant(c <= 64u) { B if (!(C)) break; }`. Nothing else changes; the unified diff is printed."""
import re, sys, difflib
src = open(sys.argv[1]).read()
start = src.index('void SampleChallenge(')
head, body = src[:start], src[start:]
n_do = len(re.findall(r'^\s*do \{\s*$', body, re.M))
assert n_do == 2, n_do
body = re.sub(r'^(\s*)do \{\s*$', r'\1while (1) __CPROVER_loop_invariant(c <= 64u) {', body, flags=re.M)
body, k = re.subn(r'^(\s*)\} while \((.*)\);\s*$', r'\1    if (!(\2)) break;\n\1}', body, flags=re.M)
assert k == 2, k
out = head + body
open(sys.argv[2], 'w').write(out)
for l in difflib.unified_diff(src.splitlines(), out.splitlines(), 'utils.c', 'utils.c(annotated)', lineterm='', n=0):
    if l[:1] in '+-' and l[:3] not in ('+++', '---'): print('overlay-sc:', l)
