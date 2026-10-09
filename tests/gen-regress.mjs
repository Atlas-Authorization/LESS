// usage: node tests/gen-regress.mjs <driver_bin> <out_dir>
// Produces regression inputs ("<pkhex> <smhex>" one line each) for the three documented defects, plus a valid sig.
import { spawnSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { writeFileSync, mkdirSync } from 'node:fs';
const [bin, out] = process.argv.slice(2);
mkdirSync(out, { recursive: true });
const run = (mode, input) => spawnSync(bin, [mode], { input, maxBuffer: 1 << 30, encoding: 'utf8' });
const msg = Buffer.from('fuzz');
const g = run('gen', `${'03'.repeat(48)} ${msg.toString('hex')}\n`);
const [pk, , smHex] = g.stdout.trim().split(' ');
const sm = Buffer.from(smHex, 'hex');
const put = (name, buf) => writeFileSync(`${out}/${name}.txt`, `${pk} ${Buffer.from(buf).toString('hex')}\n`);
const N8W = 32 * 34, HASH = 32;
put('valid', sm);
// defect 1: empty, short, and final-byte upward flip (9 -> 11)
put('d1_empty', Buffer.alloc(0));
{ const t = Buffer.from(sm.subarray(0, 40)); t[t.length-1] = 9; put("d1_short", t); }
const f = Buffer.from(sm); f[f.length - 1] ^= 0x02; put('d1_leafcount_9_to_11', f);
// defect 2: padding bits 252..255 of cf row 0 set, popcount over first 252 bits reduced by the same amount, total weight K
{
  const s = Buffer.from(sm);
  const row0 = msg.length + 2 * HASH; // cf_monom_actions[0] starts here
  // find a set bit among bits 0..251 and clear it, then set bit 252 (padding)
  let cleared = false;
  for (let b = 0; b < 252 && !cleared; b++) {
    if ((s[row0 + (b >> 3)] >> (b & 7)) & 1) { s[row0 + (b >> 3)] &= ~(1 << (b & 7)); cleared = true; }
  }
  s[row0 + 31] |= 0x10; // bit 252
  put('d2_padding_bit_row0', s);
}
// defect 3: forged digest (challenge demands more seeds than the trailing count) with valid trailing byte
{
  const s = Buffer.from(sm); randomBytes(2 * HASH).copy(s, msg.length); put('d3_forged_digest', s);
}
console.log('wrote cases to', out, 'pk bytes', pk.length / 2, 'smlen', sm.length);
