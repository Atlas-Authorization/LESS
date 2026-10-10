# LESS verifier (Atlas patch) -- sanitizer campaign summary

Build: `tests/build-native.sh` -> `less_san_O2` (ASan+UBSan, `-fno-sanitize-recover=all`, -O2) on each host.
Library under test: this branch's `Reference_Implementation/lib` (patched). Driver: `tests/less_verify_driver.c`.
Every verdict is one call to `crypto_sign_open` on a mutated or systematically altered signature.
A shard counts only if its process exited 0, it returned exactly the expected number of verdicts, stderr was
empty (no sanitizer report), and no verdict was rc 0 unless the input was the valid signature.

## 1. Fuzzing (structure-aware mutator, `tests/fuzz-mutate.mjs`)

| Segment | Mutator | Host | Mutants (verdicts) | Accepted (rc 0) | Sanitizer output | Notes |
|---|---|---|---|---|---|---|
| batches 0-4 | v1 | Mac | 20,000 | 0 | 0 | 10 shards x 400 per batch |
| batch 5 | v1 | Mac | 4,000 | 0 | 0 | shards 0,7,8 hit a 280 s alarm under load; re-run alarm-free, 400/400 each (`status142-diagnosis/`) |
| batches 6-10 | v2 | gcp | 45,000 | 0 | 0 | 9 shards x 1000 per batch |
| batches 11-15 | v2 | az1 | 45,000 | 0 | 0 | |
| batches 16-20 | v2 | az2 | 45,000 | 0 | 0 | |
| batches 21-25 | v2 | az3 | 45,000 | 0 | 0 | |
| **Fuzz total** |  |  | **204,000** | **0** | **0** | |

Not in the total: 150 verdicts in gcp `b6_s9..s11` (50 each, a leftover smoke set from another agent, all rc -1);
300 verdicts from a local v2 smoke run (`v2run`, all rc -1).

Mutator classes: v1 (bitflip, bytes, trailer, truncate, extend, digest, cf, seeds, msgbit, zero_cf) and v2 adds
numseed, lenexact, padbits, cfbit, seedbit, digestbit, msgshift, trunc_struct. Seeds are `B*1000 + S + 1`
(reproducible). Per-shard evidence: `cloud-fuzz-v2/<host>/` (`*.summary`, `*.status`, `*.err`, `*.classes`),
`fuzz-v1-batches-0-5/`.

## 2. Exhaustive all-bit sweeps (`tests/sweep-bits.sh`, every bit of the signed message and signature, one flip at a time)

Keygen seeds 0x21 / 0x31 / 0x41 (48 bytes each), messages `sig-A` / `sig-B` / `sig-C`.
Input fingerprints (sha256 prefix): A `8b7e3ad0b602ee1f`, B `aac79420136eb44a`, C `9ceb52ab5f3d3cf0`.

| Signature | sm bytes | Bit flips tried | Accepted | Shards reporting done | stderr |
|---|---|---|---|---|---|
| A | 1302 | 10,416 | 0 | 12/12 | 0 |
| B | 1302 | 10,416 | 0 | 12/12 | 0 |
| C | 1318 | 10,544 | 0 | 12/12 | 0 |

Outputs: `cloud-bit-sweeps/{A,B,C}/`.

## 3. Exhaustive single-byte sweep (signature A)

128 positions (the 64-byte signature header at sm[5..68], and the last 64 bytes of sm) x all 256 byte values = 32,768 verdicts.
Pass rule: each position has exactly one rc 0 verdict, located at the original byte value.

| Range | Host | Verdicts | rc 0 | stderr |
|---|---|---|---|---|
| positions 0-21 | az4 | 5,632 | 22 | 0 |
| positions 22-43 | az4 | 5,632 | 22 | 0 |
| positions 44-59 | az5 | 4,096 | 16 | 0 |
| positions 60-76 | az6 | 4,352 | 17 | 0 |
| positions 77-92 | az7 | 4,096 | 16 | 0 |
| positions 93-109 | az9 | 4,352 | 17 | 0 |
| positions 110-127 | az4 | 4,608 | 18 | 0 |
| **Total** | | **32,768** | **128** | **0** |

Result: 0 bad positions. Verify with `byte-sweep-A/verify.py`. Outputs: `byte-sweep-A/`.
Positions 44-110 were first started on az4, which was rebooted and then deallocated by another agent. Those shards were
not counted. They were re-sharded onto az5, az6, az7 and az9, and those results were used instead.

## 4. KAT and regress (rebuilt from the current tree)

- KAT (`kat-verify.sh`, NIST KAT CATEGORY=252 TARGET=45): 100/100 verified, rc 0, mlen matches.
- Regress (`run-regress.sh`): valid rc 0; d1_empty, d1_short, d1_leafcount_9_to_11, d2_padding_bit_row0, d3_forged_digest all rc -1, no sanitizer output.

## 5. Harness issues found and fixed (not verifier faults)

- Batch-5 status 142 was the 280 s per-shard alarm firing under machine load, not a hang: the three slowest inputs take ~0.36 s user CPU each alone (`status142-diagnosis/alone-cpu-timing.txt`).
- `less_verify_driver.c` needed `_POSIX_C_SOURCE` for `getline`/`ssize_t` on Linux (no behavioural change).
- The byte-sweep generator passed a 97 KB pk as argv (E2BIG); later it wrote 200 MB chunks to a pipe (ENOBUFS). Both fixed: input read from a file, lines written with backpressure.
- The byte-sweep input must carry the true message length (5), not 0.

## 6. Residual risk

- The verifier is C with ASan+UBSan on tested inputs only. No formal claim is made here. The CBMC proofs are separate (`tests/formal/`).
- Mutants and sweeps are finite and seeded. Coverage is structure-aware, not exhaustive over the 97 KB public key.
