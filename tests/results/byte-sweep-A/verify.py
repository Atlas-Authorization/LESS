# Verifies the exhaustive single-byte sweep of signature A. Usage: python3 verify.py (run inside this dir).
# Each range dir holds out (one "rc mlen" line per verdict, 256 per position) and origs ("P <idx> <sm_off> <orig>").
# Pass: each position has exactly one rc 0 verdict, located at the value equal to the original byte, empty stderr.
import os
ranges=[('az4','bs_0',0,22),('az4','bs_1',22,44),('az5','',44,60),('az6','',60,77),('az7','',77,93),('az9','',93,110),('az4','bs_5',110,128)]
total=0; bad=0; rc0=0
for d,pref,a,e in ranges:
    base=os.path.join(d,pref) if pref else d
    outp=base+('.out' if pref else '/out'); orp=base+('.origs' if pref else '/origs')
    st=open(base+('.status' if pref else '/status')).read().strip()
    er=os.path.getsize(base+('.err' if pref else '/err'))
    orig={}
    for line in open(orp):
        p=line.split()
        if p and p[0]=='P': orig[int(p[1])]=int(p[3])
    lines=[l.split() for l in open(outp) if l.strip()]
    zeros=[i for i,l in enumerate(lines) if l[0]=='0']
    for k in range(a,e):
        lo=(k-a)*256; hits=[i-lo for i in zeros if lo<=i<lo+256]
        if len(hits)!=1 or hits[0]!=orig.get(k,-1): bad+=1; print('BAD pos',k,hits,orig.get(k))
    total+=len(lines); rc0+=len(zeros)
    print(f"{d} {pref or 'range'} [{a},{e}) status={st!r} verdicts={len(lines)} expected={(e-a)*256} stderr_bytes={er}")
print('TOTAL verdicts',total,'expected',128*256,'rc0',rc0,'bad_positions',bad)
