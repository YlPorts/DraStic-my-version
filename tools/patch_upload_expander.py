#!/usr/bin/env python3
import struct, sys
from pathlib import Path

if len(sys.argv) != 4:
    raise SystemExit("usage: patch_upload_expander.py <input.so> <helper.bin> <output.so>")

src=Path(sys.argv[1]); helper_path=Path(sys.argv[2]); dst=Path(sys.argv[3])
data=bytearray(src.read_bytes()); helper=helper_path.read_bytes()

HELPER=0xf0600
SITES={
    0x1cf6c:(0xf90003e9,0xfeed4001),  # renderFrame top: str x9,[sp]
    0x1cfcc:(0xf90003e8,0xfeed4002),  # renderFrame bottom: str x8,[sp]
    0x1d2c8:(0xf90003f9,0xfeed4003),  # fxRender top: str x25,[sp]
    0x1d358:(0xf90003f4,0xfeed4004),  # fxRender bottom: str x20,[sp]
}

def u32(buf,off):
    return struct.unpack_from("<I",buf,off)[0]

def w32(buf,off,v):
    struct.pack_into("<I",buf,off,v & 0xffffffff)

def bl(pc,target):
    d=target-pc
    if d & 3:
        raise SystemExit("unaligned BL")
    imm=d//4
    if not (-(1<<25) <= imm < (1<<25)):
        raise SystemExit("BL out of range")
    return 0x94000000 | (imm & 0x03ffffff)

def marker_offset(value):
    raw=struct.pack("<I",value)
    hits=[]
    p=0
    while True:
        p=helper.find(raw,p)
        if p<0:
            break
        hits.append(p); p+=4
    if len(hits)!=1:
        raise SystemExit(f"marker 0x{value:08x}: {hits}")
    return hits[0]

if any(data[HELPER:HELPER+len(helper)]):
    raise SystemExit("upload expander code cave is not empty")

entries={}
for site,(expected,marker) in SITES.items():
    got=u32(data,site)
    if got != expected:
        raise SystemExit(f"site 0x{site:x}: expected 0x{expected:08x}, got 0x{got:08x}")
    entries[site]=HELPER+marker_offset(marker)+4

data[HELPER:HELPER+len(helper)] = helper
for site,target in entries.items():
    w32(data,site,bl(site,target))
    print(f"0x{site:x} -> 0x{target:x}")

dst.write_bytes(data)
print(f"Installed clean upload expander at 0x{HELPER:x}, size={len(helper)}")
