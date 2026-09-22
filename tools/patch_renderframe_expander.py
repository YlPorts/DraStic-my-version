#!/usr/bin/env python3
import struct, sys
from pathlib import Path

if len(sys.argv) != 4:
    raise SystemExit("usage: patch_renderframe_expander.py <input.so> <helper.bin> <output.so>")

src=Path(sys.argv[1]); hp=Path(sys.argv[2]); dst=Path(sys.argv[3])
data=bytearray(src.read_bytes()); helper=bytearray(hp.read_bytes())

HELPER=0xf0600
TOP_CALL=0x1cf54
BOTTOM_CALL=0x1cfb4
MARK_BOTTOM=0xfeed3001

def u32(off): return struct.unpack_from("<I",data,off)[0]
def w32(off,v): struct.pack_into("<I",data,off,v&0xffffffff)
def bl(pc,target):
    d=target-pc
    if d&3: raise SystemExit("unaligned BL")
    imm=d//4
    if not (-(1<<25)<=imm<(1<<25)): raise SystemExit("BL out of range")
    return 0x94000000|(imm&0x03ffffff)

raw=struct.pack("<I",MARK_BOTTOM)
hits=[]; p=0
while True:
    p=helper.find(raw,p)
    if p<0: break
    hits.append(p); p+=4
if len(hits)!=1: raise SystemExit(f"bottom marker hits={hits}")
BOTTOM=HELPER+hits[0]+4
w32_helper=lambda off,v: struct.pack_into("<I",helper,off,v&0xffffffff)
w32_helper(hits[0],0xd503201f)

if u32(TOP_CALL)!=0x531a6545:
    raise SystemExit(f"unexpected top instruction 0x{u32(TOP_CALL):08x}")
if u32(BOTTOM_CALL)!=0x531a6525:
    raise SystemExit(f"unexpected bottom instruction 0x{u32(BOTTOM_CALL):08x}")
if any(data[HELPER:HELPER+len(helper)]):
    raise SystemExit("renderFrame helper cave is not empty")

data[HELPER:HELPER+len(helper)]=helper
w32(TOP_CALL,bl(TOP_CALL,HELPER))
w32(BOTTOM_CALL,bl(BOTTOM_CALL,BOTTOM))
dst.write_bytes(data)
print(f"renderFrame expander installed at 0x{HELPER:x}, bottom=0x{BOTTOM:x}, size={len(helper)}")
