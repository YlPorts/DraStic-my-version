#!/usr/bin/env python3
import struct, sys
from pathlib import Path

if len(sys.argv)!=4:
    raise SystemExit("usage: patch_live_upload_expanders.py <input.so> <helper.bin> <output.so>")

src=Path(sys.argv[1]); hp=Path(sys.argv[2]); dst=Path(sys.argv[3])
data=bytearray(src.read_bytes()); helper=bytearray(hp.read_bytes())

HELPER=0xf0600
GLOBAL_PAGE=0x3f2d000
SITES={
    0x1cf54:(0x531a6545,0xfeed5000),
    0x1cfbc:(0x5281bc20,0xfeed5001),
    0x1d294:(0x52909800,0xfeed5002),
    0x1d31c:(0x53185d17,0xfeed5003),
}

def u32(buf,off): return struct.unpack_from("<I",buf,off)[0]
def w32(buf,off,v): struct.pack_into("<I",buf,off,v & 0xffffffff)
def bl(pc,target):
    d=target-pc
    if d&3: raise SystemExit("unaligned BL")
    imm=d//4
    if not (-(1<<25)<=imm<(1<<25)): raise SystemExit("BL out of range")
    return 0x94000000 | (imm & 0x03ffffff)
def adrp(rd,pc,target):
    imm=((target & ~0xfff)-(pc & ~0xfff))>>12
    if not (-(1<<20)<=imm<(1<<20)): raise SystemExit("ADRP out of range")
    v=imm & ((1<<21)-1)
    return 0x90000000 | ((v&3)<<29) | (((v>>2)&0x7ffff)<<5) | rd
def hits(value):
    raw=struct.pack("<I",value); out=[]; p=0
    while True:
        p=helper.find(raw,p)
        if p<0: break
        out.append(p); p+=4
    return out

entries={}
for site,(expected,mark) in SITES.items():
    hs=hits(mark)
    if len(hs)!=1: raise SystemExit(f"entry marker {mark:x}: {hs}")
    entries[site]=HELPER+hs[0]+4
    if u32(data,site)!=expected:
        raise SystemExit(f"site 0x{site:x}: expected 0x{expected:08x}, got 0x{u32(data,site):08x}")

hs=hits(0xfeed50a0)
if len(hs)!=1: raise SystemExit(f"ADRP marker hits={hs}")
w32(helper,hs[0],adrp(6,HELPER+hs[0],GLOBAL_PAGE))

if any(data[HELPER:HELPER+len(helper)]):
    raise SystemExit("combined helper cave not empty")

data[HELPER:HELPER+len(helper)]=helper
for site,target in entries.items():
    w32(data,site,bl(site,target))

dst.write_bytes(data)
print("Installed live upload expanders:")
for site,target in entries.items():
    print(f"  0x{site:x} -> 0x{target:x}")
print(f"helper size={len(helper)}")
