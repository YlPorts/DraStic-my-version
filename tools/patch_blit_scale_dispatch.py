#!/usr/bin/env python3
import struct, sys
from pathlib import Path

if len(sys.argv) != 3:
    raise SystemExit("usage: patch_blit_scale_dispatch.py <input.so> <output.so>")

src=Path(sys.argv[1])
dst=Path(sys.argv[2])
data=bytearray(src.read_bytes())

BLIT_CALL_VA=0x80128
HELPER_VA=0xf00a4
CFG_PAGE=0x14c000

def u32(off):
    return struct.unpack_from("<I", data, off)[0]

def w32(off, val):
    struct.pack_into("<I", data, off, val & 0xffffffff)

def encode_bl(pc, target):
    delta=target-pc
    if delta % 4:
        raise SystemExit("unaligned BL target")
    imm=delta//4
    if not (-(1<<25) <= imm < (1<<25)):
        raise SystemExit("BL out of range")
    return 0x94000000 | (imm & 0x03ffffff)

def encode_adrp(rd, pc, target):
    imm=((target & ~0xfff) - (pc & ~0xfff)) >> 12
    if not (-(1<<20) <= imm < (1<<20)):
        raise SystemExit("ADRP out of range")
    v=imm & ((1<<21)-1)
    return 0x90000000 | ((v & 3)<<29) | (((v>>2)&0x7ffff)<<5) | rd

# Original instruction is "mov w24, w5".
expected=0x2a0503f8
if u32(BLIT_CALL_VA) != expected:
    raise SystemExit(f"unexpected instruction at 0x{BLIT_CALL_VA:x}: 0x{u32(BLIT_CALL_VA):08x}")

# The selected code cave is unused zero-filled executable .text.
helper_words=[
    encode_adrp(16, HELPER_VA, CFG_PAGE), # x16 = page containing packed config
    0xf9423610,                           # ldr x16, [x16, #0x468]
    0xd373d210,                           # ubfx x16, x16, #51, #2
    0x11000618,                           # add w24, w16, #1
    0xd65f03c0,                           # ret
]
helper_size=4*len(helper_words)
if any(data[HELPER_VA:HELPER_VA+helper_size]):
    raise SystemExit("selected code cave is not empty")

for i,word in enumerate(helper_words):
    w32(HELPER_VA+4*i, word)

w32(BLIT_CALL_VA, encode_bl(BLIT_CALL_VA, HELPER_VA))

dst.write_bytes(data)
print(f"Patched blit scale dispatch at 0x{BLIT_CALL_VA:x} -> helper 0x{HELPER_VA:x}")
print("Helper forces the compositor's specialized scaler to use packed scale bits 51-52 + 1.")
