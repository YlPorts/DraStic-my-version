#!/usr/bin/env python3
import struct
import sys
from pathlib import Path

if len(sys.argv) != 4:
    raise SystemExit("usage: patch_dynamic_hires_unpacker.py <input.so> <helper.bin> <output.so>")

src = Path(sys.argv[1])
helper_path = Path(sys.argv[2])
dst = Path(sys.argv[3])

data = bytearray(src.read_bytes())
helper = bytearray(helper_path.read_bytes())

ENTRY_VA = 0x4CB84
HELPER_VA = 0xF0100
GET_SCALE_INDEX_VA = 0x1CDAC
ORIGINAL_2X_CONTINUE_VA = 0x4CB88
RETURN_VA = 0x4D284

MARK_BL_GET = 0xFEED0001
MARK_B_2X = 0xFEED0002
MARK_B_DONE = 0xFEED0003

def u32(buf, off):
    return struct.unpack_from("<I", buf, off)[0]

def w32(buf, off, value):
    struct.pack_into("<I", buf, off, value & 0xffffffff)

def branch(pc, target, link=False):
    delta = target - pc
    if delta & 3:
        raise SystemExit(f"unaligned branch 0x{pc:x}->0x{target:x}")
    imm = delta // 4
    if not (-(1 << 25) <= imm < (1 << 25)):
        raise SystemExit("branch out of range")
    return (0x94000000 if link else 0x14000000) | (imm & 0x03ffffff)

def replace_marker(marker, target, link):
    raw = struct.pack("<I", marker)
    positions = []
    pos = 0
    while True:
        pos = helper.find(raw, pos)
        if pos < 0:
            break
        positions.append(pos)
        pos += 4
    if len(positions) != 1:
        raise SystemExit(f"marker 0x{marker:08x}: expected 1, found {len(positions)}")
    off = positions[0]
    w32(helper, off, branch(HELPER_VA + off, target, link))

# Original instruction at 0x4cb84 is: add x8, x0, #0x800
EXPECTED_ENTRY = 0x91200008
if u32(data, ENTRY_VA) != EXPECTED_ENTRY:
    raise SystemExit(
        f"unexpected entry instruction at 0x{ENTRY_VA:x}: 0x{u32(data, ENTRY_VA):08x}"
    )

# Cave is after the small J helper; it must still be zero-filled.
if any(data[HELPER_VA:HELPER_VA + len(helper)]):
    raise SystemExit("dynamic unpacker code cave is not empty")

replace_marker(MARK_BL_GET, GET_SCALE_INDEX_VA, True)
replace_marker(MARK_B_2X, ORIGINAL_2X_CONTINUE_VA, False)
replace_marker(MARK_B_DONE, RETURN_VA, False)

data[HELPER_VA:HELPER_VA + len(helper)] = helper
w32(data, ENTRY_VA, branch(ENTRY_VA, HELPER_VA, False))

dst.write_bytes(data)
print(f"Dynamic HiRes unpacker installed at 0x{HELPER_VA:x}, {len(helper)} bytes")
print(f"0x{ENTRY_VA:x} now branches to the dynamic unpacker")
