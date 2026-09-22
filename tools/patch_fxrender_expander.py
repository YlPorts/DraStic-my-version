#!/usr/bin/env python3
import struct, sys
from pathlib import Path

if len(sys.argv)!=4:
    raise SystemExit("usage: patch_fxrender_expander.py <input.so> <helper.bin> <output.so>")

src=Path(sys.argv[1]); hp=Path(sys.argv[2]); dst=Path(sys.argv[3])
data=bytearray(src.read_bytes()); helper=bytearray(hp.read_bytes())

HELPER=0xf0900
COMMON=0xf063c
TOP_CALL=0x1d294
BOTTOM_CALL=0x1d31c
MARK_BL_TOP=0xfeed4001
MARK_BOTTOM=0xfeed4002
MARK_BL_BOTTOM=0xfeed4003

def u32(off):
    return struct.unpack_from("<I",data,off)[0]
def w32(buf,off,v):
    struct.pack_into("<I",buf,off,v & 0xffffffff)
def bl(pc,target):
    d=target-pc
    if d&3: raise SystemExit("unaligned BL")
    imm=d//4
    if not (-(1<<25)<=imm<(1<<25)): raise SystemExit("BL out of range")
    return 0x94000000 | (imm & 0x03ffffff)
def find_marker(value):
    raw=struct.pack("<I",value); hits=[]; p=0
    while True:
        p=helper.find(raw,p)
        if p<0: break
        hits.append(p); p+=4
    if len(hits)!=1:
        raise SystemExit(f"marker 0x{value:x}: {hits}")
    return hits[0]

top_bl=find_marker(MARK_BL_TOP)
bottom_mark=find_marker(MARK_BOTTOM)
bottom_bl=find_marker(MARK_BL_BOTTOM)
w32(helper,top_bl,bl(HELPER+top_bl,COMMON))
w32(helper,bottom_bl,bl(HELPER+bottom_bl,COMMON))
BOTTOM=HELPER+bottom_mark+4

# Original instructions in fxRender.
if u32(TOP_CALL)!=0x52909800:
    raise SystemExit(f"unexpected fx top call site: 0x{u32(TOP_CALL):08x}")
if u32(BOTTOM_CALL)!=0x53185d17:
    raise SystemExit(f"unexpected fx bottom call site: 0x{u32(BOTTOM_CALL):08x}")
if any(data[HELPER:HELPER+len(helper)]):
    raise SystemExit("fx helper cave not empty")

data[HELPER:HELPER+len(helper)] = helper
struct.pack_into("<I",data,TOP_CALL,bl(TOP_CALL,HELPER))
struct.pack_into("<I",data,BOTTOM_CALL,bl(BOTTOM_CALL,BOTTOM))

dst.write_bytes(data)
print(f"fxRender adapters installed at 0x{HELPER:x}, bottom=0x{BOTTOM:x}")
