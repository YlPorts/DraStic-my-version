#!/usr/bin/env python3
import struct, sys
from pathlib import Path

if len(sys.argv) != 4:
    raise SystemExit("usage: patch_upload_source_expander.py <input.so> <helper.bin> <output.so>")

src=Path(sys.argv[1]); hp=Path(sys.argv[2]); dst=Path(sys.argv[3])
data=bytearray(src.read_bytes()); helper=bytearray(hp.read_bytes())

HELPER=0xf0600
GLOBAL_PAGE=0x3f2d000
SITES={
  0xfeed4101:("render_top",0x1cf54,0x531a6545),
  0xfeed4102:("render_bottom",0x1cfb8,0x9ba85ea8),
  0xfeed4103:("fx_top",0x1d28c,0x9ba83539),
  0xfeed4104:("fx_bottom",0x1d310,0x9b092d54),
}

def u32(buf,off): return struct.unpack_from("<I",buf,off)[0]
def w32(buf,off,v): struct.pack_into("<I",buf,off,v & 0xffffffff)

def bl(pc,target):
    d=target-pc
    if d & 3: raise SystemExit("unaligned BL")
    imm=d//4
    if not (-(1<<25) <= imm < (1<<25)): raise SystemExit("BL out of range")
    return 0x94000000 | (imm & 0x03ffffff)

def adrp(rd,pc,target):
    imm=((target & ~0xfff)-(pc & ~0xfff))>>12
    if not (-(1<<20) <= imm < (1<<20)): raise SystemExit("ADRP out of range")
    v=imm & ((1<<21)-1)
    return 0x90000000 | ((v&3)<<29) | (((v>>2)&0x7ffff)<<5) | rd

def find_marker(m):
    raw=struct.pack("<I",m); hits=[]; p=0
    while True:
        p=helper.find(raw,p)
        if p<0: break
        hits.append(p); p+=4
    if len(hits)!=1: raise SystemExit(f"marker {m:#x}: hits={hits}")
    return hits[0]

entries={}
for m,(name,site,expected) in SITES.items():
    off=find_marker(m)
    entries[name]=HELPER+off+4
    got=u32(data,site)
    if got!=expected:
        raise SystemExit(f"{name}: site {site:#x} expected {expected:08x}, got {got:08x}")

off=find_marker(0xfeed4105)
w32(helper,off,adrp(14,HELPER+off,GLOBAL_PAGE))

if any(data[HELPER:HELPER+len(helper)]):
    raise SystemExit("helper cave not empty")

data[HELPER:HELPER+len(helper)]=helper
for m,(name,site,expected) in SITES.items():
    w32(data,site,bl(site,entries[name]))

dst.write_bytes(data)
print("installed",entries)
