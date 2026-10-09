// Structure-aware mutation fuzzer for crypto_sign_open (the PATCHED reference verifier).
// Streams "<pkhex> <smhex>" lines to stdout (pipe into `less_verify_driver open`) and writes one
// mutation-class name per line to a sidecar file, so every verdict can be attributed to its class.
//
// Usage: node fuzz-mutate.mjs <gen_bin> <count> <prng_seed_int> <sidecar_path> [n_bases]
//   gen_bin : the driver built natively (its `gen` mode signs with the reference, `open` verifies)
//   count   : number of mutated signatures to emit
//   Mutations never produce the original bytes (each mutant is re-drawn if it equals its base).
// Base signatures are fresh keypairs/signatures from the reference (seeded, reproducible).
import { spawnSync } from 'node:child_process';
import { openSync, writeSync, closeSync } from 'node:fs';

const [genBin, countStr, seedStr, sidecar, basesStr] = process.argv.slice(2);
const COUNT = Number(countStr);
const NB = Number(basesStr ?? 4);
const HASH = 32;
const N8W = 32 * 34;            // cf_monom_actions: 34 rows x 32 bytes
const MSG = Buffer.from('fuzz');

// mulberry32: small reproducible PRNG
let st = (Number(seedStr) >>> 0) || 1;
const rnd32 = () => { st = (st + 0x6d2b79f5) >>> 0; let t = st; t = Math.imul(t ^ (t >>> 15), t | 1);
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0); };
const ri = (n) => rnd32() % n;                     // [0, n)
const rbyte = () => ri(256);

const bases = [];
for (let b = 0; b < NB; b++) {
  const seed = Buffer.alloc(48, 0x11 + b).toString('hex');
  const msg = Buffer.concat([MSG, Buffer.from([b])]);
  const g = spawnSync(genBin, ['gen'], { input: `${seed} ${msg.toString('hex')}\n`, maxBuffer: 1 << 30, encoding: 'utf8' });
  if (g.status !== 0) { console.error('gen failed', g.status); process.exit(1); }
  const [pk, , smHex, rc] = g.stdout.trim().split(' ');
  if (rc !== '0') { console.error('base sig did not verify rc=', rc); process.exit(1); }
  bases.push({ pk, sm: Buffer.from(smHex, 'hex'), mlen: msg.length });
}

const CLASSES = ['bitflip', 'bytes', 'trailer', 'truncate', 'extend', 'digest', 'cf', 'seeds', 'msgbit', 'zero_cf'];
function mutate(cls, base) {
  const sm = Buffer.from(base.sm);
  const L = sm.length, sigOff = base.mlen, sigLen = L - sigOff;
  switch (cls) {
    case 'bitflip': { const k = 1 + ri(8); for (let i = 0; i < k; i++) sm[ri(L)] ^= 1 << ri(8); return sm; }
    case 'bytes': { const k = 1 + ri(16); for (let i = 0; i < k; i++) sm[ri(L)] = rbyte(); return sm; }
    case 'trailer': sm[L - 1] = rbyte(); return sm;
    case 'truncate': return sm.subarray(0, Math.max(0, L - 1 - ri(Math.min(200, L))));
    case 'extend': { const k = 1 + ri(64); return Buffer.concat([sm, Buffer.from(Array.from({ length: k }, rbyte))]); }
    case 'digest': for (let i = 0; i < 2 * HASH; i++) sm[sigOff + i] = rbyte(); return sm;
    case 'cf': for (let i = 0; i < N8W; i++) sm[sigOff + 2 * HASH + i] = rbyte(); return sm;
    case 'seeds': { const o = sigOff + 2 * HASH + N8W, e = L - 1; for (let i = o; i < e; i++) sm[i] = rbyte(); return sm; }
    case 'msgbit': sm[ri(sigOff)] ^= 1 << ri(8); return sm;
    case 'zero_cf': for (let i = 0; i < N8W; i++) sm[sigOff + 2 * HASH + i] = 0; return sm;
  }
  throw new Error(cls);
}

const fd = openSync(sidecar, 'w');
const out = process.stdout;
const CH = 500;
let buf = [], side = [], emitted = 0;
async function flush() {
  if (!buf.length) return;
  const ok = out.write(buf.join(''));
  writeSync(fd, side.join(''));
  buf = []; side = [];
  if (!ok) await new Promise((r) => out.once('drain', r));
}
(async () => {
  for (let n = 0; n < COUNT; n++) {
    const base = bases[ri(bases.length)];
    let cls, m;
    do { cls = CLASSES[ri(CLASSES.length)]; m = mutate(cls, base); } while (m.equals(base.sm));
    buf.push(`${base.pk} ${m.toString('hex')}\n`);
    side.push(`${cls}\n`);
    if (buf.length >= CH) await flush();
    emitted++;
  }
  await flush();
  closeSync(fd);
  console.error(`emitted ${emitted}`);
})().catch((e) => { if (e.code !== 'EPIPE') console.error(e); process.exit(0); });
out.on('error', () => process.exit(0));
