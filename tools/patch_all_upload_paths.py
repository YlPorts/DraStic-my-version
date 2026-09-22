#!/usr/bin/env python3
import struct, sys
from pathlib import Path

if len(sys.argv) != 4:
    raise SystemExit("usage: patch_all_upload_paths.py <input.so> <helper.bin> <output.so>")

src=Path(sys.argv[1]); hb=Path(sys.argv[2]); dst=Path(sys.argv[3])
data=bytearray(src.read_bytes()); helper=bytearray(hb.read_bytes())

HELPER=0xf0a00
CFG_GLOBALS=0x3f2d000
MARKERS={
  0xfeed4001:0x1cf6c,  # render top: str x9,[sp]
  0xfeed4002:0x1cfcc,  # render bottom: str x8,[sp]
  0xfeed4003:0x1d2c8,  # fx top: str x25,[sp]
  0xfeed4004:0x1d358,  # fx bottom: str x20,[sp]
}
EXPECTED={
  0x1cf6c:0xf90003e9,
  0x1cfcc:0xf90003e8,
  0x1d2c8:0xf90003f9,
  0x1d358:0xf90003f4,
}

def u32(buf,off): return struct.unpack_from("<I",buf,off)[0]
def w32(buf,off,v): struct.pack_into("<I",buf,off,v & 0xffffffff)

def bl(pc,target):
    d=target-pc
    if d & 3: raise SystemExit("unaligned BL")
    imm=d//4
    if not (-(1<<25)<=imm<(1<<25)): raise SystemExit("BL out of range")
    return 0x94000000 | (imm & 0x03ffffff)

def adrp(rd,pc,target):
    imm=((target & ~0xfff)-(pc & ~0xfff))>>12
    if not (-(1<<20)<=imm<(1<<20)): raise SystemExit("ADRP out of range")
    v=imm & ((1<<21)-1)
    return 0x90000000 | ((v & 3)<<29) | (((v>>2)&0x7ffff)<<5) | rd

# Locate all entry markers and replace the scratch ADRP marker.
entries={}
for marker,patch_va in MARKERS.items():
    raw=struct.pack("<I",marker)
    hits=[]; p=0
    while True:
        p=helper.find(raw,p)
        if p<0: break
        hits.append(p); p+=4
    if len(hits)!=1: raise SystemExit(f"marker {marker:x}: {hits}")
    entries[patch_va]=HELPER+hits[0]+4

raw=struct.pack("<I",0xfeed4005)
hits=[]; p=0
while True:
    p=helper.find(raw,p)
    if p<0: break
    hits.append(p); p+=4
if len(hits)!=1: raise SystemExit(f"scratch marker hits={hits}")
o=hits[0]
w32(helper,o,adrp(9,HELPER+o,CFG_GLOBALS))

for va,expected in EXPECTED.items():
    if u32(data,va)!=expected:
        raise SystemExit(f"unexpected opcode at 0x{va:x}: 0x{u32(data,va):08x}")

if any(data[HELPER:HELPER+len(helper)]):
    raise SystemExit("helper cave not empty")

data[HELPER:HELPER+len(helper)]=helper
for va,target in entries.items():
    w32(data,va,bl(va,target))

dst.write_bytes(data)
for va,target in entries.items():
    print(f"0x{va:x} -> BL 0x{target:x}")
print(f"upload helper installed at 0x{HELPER:x}, size={len(helper)}")
