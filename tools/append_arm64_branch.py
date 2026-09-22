#!/usr/bin/env python3
import struct, sys
from pathlib import Path
if len(sys.argv)!=4:
    raise SystemExit("usage: append_arm64_branch.py <blob> <patch_va> <target_va>")
p=Path(sys.argv[1]); start=int(sys.argv[2],0); target=int(sys.argv[3],0)
data=bytearray(p.read_bytes())
pc=start+len(data)
delta=target-pc
if delta % 4:
    raise SystemExit("unaligned branch")
imm=delta//4
if not -(1<<25) <= imm < (1<<25):
    raise SystemExit("branch out of range")
insn=0x14000000 | (imm & 0x03ffffff)
data += struct.pack("<I",insn)
p.write_bytes(data)
print(f"branch VA 0x{pc:x} -> 0x{target:x}, insn=0x{insn:08x}, size={len(data)}")
