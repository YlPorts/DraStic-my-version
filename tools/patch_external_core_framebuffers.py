#!/usr/bin/env python3
import struct, sys
from pathlib import Path

if len(sys.argv) != 4:
    raise SystemExit("usage: patch_external_core_framebuffers.py <input.so> <helper.bin> <output.so>")

src=Path(sys.argv[1])
helper_path=Path(sys.argv[2])
dst=Path(sys.argv[3])

data=bytearray(src.read_bytes())
helper=bytearray(helper_path.read_bytes())

ENTRY=0x5fb28
HELPER=0xf0300
MALLOC=0x15ea0
MEMSET=0x16570

MARK_MALLOC=0xfeed1001
MARK_MEMSET=0xfeed1002

def u32(buf, off):
    return struct.unpack_from("<I", buf, off)[0]

def w32(buf, off, value):
    struct.pack_into("<I", buf, off, value & 0xffffffff)

def branch(pc, target, link=False):
    d=target-pc
    if d & 3:
        raise SystemExit("unaligned branch")
    imm=d//4
    if not (-(1<<25) <= imm < (1<<25)):
        raise SystemExit("branch out of range")
    return (0x94000000 if link else 0x14000000) | (imm & 0x03ffffff)

def replace_marker(marker, target):
    raw=struct.pack("<I", marker)
    hits=[]
    p=0
    while True:
        p=helper.find(raw,p)
        if p<0: break
        hits.append(p); p+=4
    if len(hits)!=1:
        raise SystemExit(f"marker 0x{marker:x}: {len(hits)} hits")
    off=hits[0]
    w32(helper, off, branch(HELPER+off,target,True))

# Original prologue: str x21,[sp,#-48]!
if u32(data,ENTRY) != 0xf81d0ff5:
    raise SystemExit(f"unexpected instruction at 0x{ENTRY:x}: 0x{u32(data,ENTRY):08x}")

if any(data[HELPER:HELPER+len(helper)]):
    raise SystemExit("selected code cave is not empty")

replace_marker(MARK_MALLOC,MALLOC)
replace_marker(MARK_MEMSET,MEMSET)

data[HELPER:HELPER+len(helper)] = helper
w32(data,ENTRY,branch(ENTRY,HELPER,False))

dst.write_bytes(data)
print(f"Installed external 6 MiB core framebuffer pair helper at 0x{HELPER:x}")
print(f"Redirected original initializer 0x{ENTRY:x} to helper")
