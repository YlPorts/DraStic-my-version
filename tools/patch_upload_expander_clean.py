#!/usr/bin/env python3
import hashlib, struct, sys
from pathlib import Path

if len(sys.argv) != 4:
    raise SystemExit("usage: patch_upload_expander_clean.py <input.so> <helper.bin> <output.so>")

src=Path(sys.argv[1]); helper_path=Path(sys.argv[2]); dst=Path(sys.argv[3])
data=bytearray(src.read_bytes()); helper=bytearray(helper_path.read_bytes())

EXPECTED_SHA="3b27eee0c480df818e5adfde227f4b92ce57bc468562f7f7f079a121b8dcd902"
HELPER=0xF0600
CFG_PAGE=0x14C000
GLOBAL_PAGE=0x3F2D000

if hashlib.sha256(data).hexdigest() != EXPECTED_SHA:
    raise SystemExit("unexpected pristine native sha")

def u32(buf, off):
    return struct.unpack_from("<I", buf, off)[0]
def w32(buf, off, value):
    struct.pack_into("<I", buf, off, value & 0xffffffff)
def bl(pc, target):
    delta=target-pc
    if delta & 3:
        raise SystemExit("unaligned BL")
    imm=delta//4
    if not (-(1<<25) <= imm < (1<<25)):
        raise SystemExit("BL out of range")
    return 0x94000000 | (imm & 0x03ffffff)
def adrp(rd, pc, target):
    imm=((target & ~0xfff) - (pc & ~0xfff)) >> 12
    if not (-(1<<20) <= imm < (1<<20)):
        raise SystemExit("ADRP out of range")
    v=imm & ((1<<21)-1)
    return 0x90000000 | ((v & 3) << 29) | (((v >> 2) & 0x7ffff) << 5) | rd
def find_marker(marker):
    raw=struct.pack("<I", marker)
    hits=[]; pos=0
    while True:
        pos=helper.find(raw,pos)
        if pos < 0:
            break
        hits.append(pos); pos += 4
    if len(hits) != 1:
        raise SystemExit(f"marker 0x{marker:08x}: {hits}")
    return hits[0]

render_bottom=HELPER + find_marker(0xfeed4101) + 4
fx_top=HELPER + find_marker(0xfeed4102) + 4
fx_bottom=HELPER + find_marker(0xfeed4103) + 4

o=find_marker(0xfeed4001)
w32(helper,o,adrp(9,HELPER+o,CFG_PAGE))
o=find_marker(0xfeed4002)
w32(helper,o,adrp(11,HELPER+o,GLOBAL_PAGE))

if any(data[HELPER:HELPER+len(helper)]):
    raise SystemExit("helper cave is not empty")
data[HELPER:HELPER+len(helper)] = helper

sites=[
    (0x1CF6C, 0xF90003E9, HELPER),
    (0x1CFCC, 0xF90003E8, render_bottom),
    (0x1D2C8, 0xF90003F9, fx_top),
    (0x1D358, 0xF90003F4, fx_bottom),
]
for site, expected, target in sites:
    got=u32(data,site)
    if got != expected:
        raise SystemExit(f"unexpected instruction at 0x{site:x}: 0x{got:08x}")
    w32(data,site,bl(site,target))

# Keep DraStic's original 1x/2x layout untouched. Only reserve 3 MiB
# extra scratch after its original 3 MiB renderer block.
for site in (0x1CC34, 0x1CC50):
    got=u32(data,site)
    if got != 0x52A00602:
        raise SystemExit(f"unexpected allocation instruction at 0x{site:x}: 0x{got:08x}")
    w32(data,site,0x52A00C02)

dst.write_bytes(data)
print("renderFrame/fxRender upload expander installed")
print("helper bytes:", len(helper))
print("output sha256:", hashlib.sha256(data).hexdigest())
