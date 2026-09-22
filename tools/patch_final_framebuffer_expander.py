#!/usr/bin/env python3
import struct, sys
from pathlib import Path

if len(sys.argv) != 4:
    raise SystemExit("usage: patch_final_framebuffer_expander.py <input.so> <helper.bin> <output.so>")

src=Path(sys.argv[1])
helper_path=Path(sys.argv[2])
dst=Path(sys.argv[3])

data=bytearray(src.read_bytes())
helper=bytearray(helper_path.read_bytes())

TAIL_VA=0x5f100
HELPER_VA=0xf0400
CFG_PAGE=0x14c000
MEMCPY_VA=0x15b30

MARK_ADRP=0xfeed2001
MARK_B_MEMCPY=0xfeed2002

def u32(buf, off):
    return struct.unpack_from("<I", buf, off)[0]

def w32(buf, off, value):
    struct.pack_into("<I", buf, off, value & 0xffffffff)

def branch(pc,target,link=False):
    d=target-pc
    if d & 3:
        raise SystemExit("unaligned branch")
    imm=d//4
    if not (-(1<<25) <= imm < (1<<25)):
        raise SystemExit("branch out of range")
    return (0x94000000 if link else 0x14000000) | (imm & 0x03ffffff)

def adrp(rd, pc, target):
    imm=((target & ~0xfff) - (pc & ~0xfff)) >> 12
    if not (-(1<<20) <= imm < (1<<20)):
        raise SystemExit("ADRP out of range")
    v=imm & ((1<<21)-1)
    return 0x90000000 | ((v & 3)<<29) | (((v>>2)&0x7ffff)<<5) | rd

def marker(marker):
    raw=struct.pack("<I",marker)
    hits=[]
    p=0
    while True:
        p=helper.find(raw,p)
        if p<0: break
        hits.append(p); p+=4
    if len(hits)!=1:
        raise SystemExit(f"marker 0x{marker:x}: expected 1, got {len(hits)}")
    return hits[0]

# Current full patch tail is a direct B memcpy.
old=u32(data,TAIL_VA)
if (old & 0xfc000000) != 0x14000000:
    raise SystemExit(f"unexpected tail at 0x{TAIL_VA:x}: 0x{old:08x}")

if any(data[HELPER_VA:HELPER_VA+len(helper)]):
    raise SystemExit("selected helper cave is not empty")

o=marker(MARK_ADRP)
w32(helper,o,adrp(9,HELPER_VA+o,CFG_PAGE))

o=marker(MARK_B_MEMCPY)
w32(helper,o,branch(HELPER_VA+o,MEMCPY_VA,False))

data[HELPER_VA:HELPER_VA+len(helper)] = helper
w32(data,TAIL_VA,branch(TAIL_VA,HELPER_VA,False))

dst.write_bytes(data)
print(f"Installed final framebuffer expander at 0x{HELPER_VA:x}")
print(f"Replaced tail memcpy branch at 0x{TAIL_VA:x}")
