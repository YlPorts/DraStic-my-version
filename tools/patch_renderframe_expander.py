#!/usr/bin/env python3
import struct, sys
from pathlib import Path

if len(sys.argv) != 4:
    raise SystemExit("usage: patch_renderframe_expander.py <input.so> <helper.bin> <output.so>")

src=Path(sys.argv[1]); helper_path=Path(sys.argv[2]); dst=Path(sys.argv[3])
data=bytearray(src.read_bytes()); helper=helper_path.read_bytes()

HELPER=0xf0600
TOP=HELPER
BOTTOM=None
TOP_CALL=0x1cf54
BOTTOM_CALL=0x1cfbc

def u32(off):
    return struct.unpack_from("<I", data, off)[0]
def w32(off,v):
    struct.pack_into("<I", data, off, v & 0xffffffff)
def bl(pc,target):
    d=target-pc
    if d & 3: raise SystemExit("unaligned BL")
    imm=d//4
    if not (-(1<<25) <= imm < (1<<25)): raise SystemExit("BL out of range")
    return 0x94000000 | (imm & 0x03ffffff)

def one_marker(value):
    raw=struct.pack("<I",value)
    hits=[]
    p=0
    while True:
        p=helper.find(raw,p)
        if p<0:
            break
        hits.append(p)
        p+=4
    if len(hits)!=1:
        raise SystemExit(f"marker 0x{value:08x} hits={hits}")
    return hits[0]

bottom_off=one_marker(0xfeed3001)
fx_top_off=one_marker(0xfeed3002)
fx_bottom_off=one_marker(0xfeed3003)
adrp_fx_top=one_marker(0xfeed3101)
adrp_fx_bottom=one_marker(0xfeed3102)

BOTTOM=HELPER+bottom_off+4
FX_TOP=HELPER+fx_top_off+4
FX_BOTTOM=HELPER+fx_bottom_off+4

def adrp(rd, pc, target):
    imm=((target & ~0xfff) - (pc & ~0xfff)) >> 12
    if not (-(1<<20) <= imm < (1<<20)):
        raise SystemExit("ADRP out of range")
    v=imm & ((1<<21)-1)
    return 0x90000000 | ((v & 3)<<29) | (((v>>2)&0x7ffff)<<5) | rd

helper_mut=bytearray(helper)
struct.pack_into("<I", helper_mut, adrp_fx_top, adrp(27, HELPER+adrp_fx_top, CFG_PAGE))
struct.pack_into("<I", helper_mut, adrp_fx_bottom, adrp(27, HELPER+adrp_fx_bottom, CFG_PAGE))
helper=bytes(helper_mut)

if u32(TOP_CALL) != 0x531a6545:
    raise SystemExit(f"unexpected top instruction 0x{u32(TOP_CALL):08x}")
if u32(BOTTOM_CALL) != 0x5281bc20:
    raise SystemExit(f"unexpected bottom instruction 0x{u32(BOTTOM_CALL):08x}")
if any(data[HELPER:HELPER+len(helper)]):
    raise SystemExit("renderFrame helper cave is not empty")

data[HELPER:HELPER+len(helper)]=helper
w32(TOP_CALL,bl(TOP_CALL,TOP))
w32(BOTTOM_CALL,bl(BOTTOM_CALL,BOTTOM))
w32(FX_TOP_CALL,bl(FX_TOP_CALL,FX_TOP))
w32(FX_BOTTOM_CALL,bl(FX_BOTTOM_CALL,FX_BOTTOM))

dst.write_bytes(data)
print(f"expander installed at 0x{HELPER:x}, render bottom=0x{BOTTOM:x}, fx top=0x{FX_TOP:x}, fx bottom=0x{FX_BOTTOM:x}, size={len(helper)}")
