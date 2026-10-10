// Single-byte exhaustive sweep input generator: for each signed-message byte position in the requested
// window, emits ALL 256 byte values (including the original, which must verify) as "<pkhex> <smhex>" lines
// for `less_verify_driver open`. A side record "P <window_idx> <sm_offset> <orig_byte>" goes to stderr.
// Positions (128 total): the 64-byte signature header (digest, sm[mlen..mlen+63]) and the last 64 bytes of sm.
// Usage: node byte-sweep.mjs <input_file "pk sm mlen"> <first_idx> <end_idx>
// The input is read from a file (a 97 KB pk hex exceeds the per-argument limit). Lines are written one at a
// time with backpressure: writing whole windows at once overflows the pipe buffer (ENOBUFS).
import { readFileSync } from 'node:fs';
const [inPath, aStr, bStr] = process.argv.slice(2);
const [pk, smHex, mlenStr] = readFileSync(inPath, 'utf8').trim().split(/\s+/);
const sm = Buffer.from(smHex, 'hex'), L = sm.length, mlen = Number(mlenStr);
if (!(mlen > 0)) { console.error('mlen must be the true message length (>0)'); process.exit(2); }
const pos = [];
for (let i = 0; i < 64; i++) pos.push(mlen + i);
for (let i = 0; i < 64; i++) pos.push(L - 64 + i);
const a = Number(aStr), b = Number(bStr);
const write = (s) => new Promise((res) => { if (process.stdout.write(s)) res(); else process.stdout.once('drain', res); });
(async () => {
  for (let k = a; k < b; k++) {
    const p = pos[k];
    console.error(`P ${k} ${p} ${sm[p]}`);
    for (let v = 0; v < 256; v++) {
      const m = Buffer.from(sm); m[p] = v;
      await write(`${pk} ${m.toString('hex')}\n`);
    }
  }
})().catch((e) => { if (e.code !== 'EPIPE') console.error(e); process.exit(e.code === 'EPIPE' ? 0 : 1); });
