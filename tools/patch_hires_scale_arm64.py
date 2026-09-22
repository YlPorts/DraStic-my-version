#!/usr/bin/env python3
import argparse
import hashlib
import struct
from pathlib import Path

EXPECTED_SHA256 = "3b27eee0c480df818e5adfde227f4b92ce57bc468562f7f7f079a121b8dcd902"
PATCH_VADDR = 0x1CE04
PATCH_SIZE = 8 * 4  # 8 AArch64 instructions

def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def vaddr_to_offset(data: bytes, vaddr: int) -> int:
    if data[:4] != b"\x7fELF":
        raise ValueError("Not an ELF file")
    if data[4] != 2 or data[5] != 1:
        raise ValueError("Expected ELF64 little-endian")

    e_phoff = struct.unpack_from("<Q", data, 0x20)[0]
    e_phentsize = struct.unpack_from("<H", data, 0x36)[0]
    e_phnum = struct.unpack_from("<H", data, 0x38)[0]

    PT_LOAD = 1
    for i in range(e_phnum):
        off = e_phoff + i * e_phentsize
        p_type, p_flags = struct.unpack_from("<II", data, off)
        p_offset, p_vaddr, p_paddr, p_filesz, p_memsz, p_align = struct.unpack_from("<QQQQQQ", data, off + 8)
        if p_type != PT_LOAD:
            continue
        if p_vaddr <= vaddr < p_vaddr + p_filesz:
            return p_offset + (vaddr - p_vaddr)
    raise ValueError(f"Virtual address 0x{vaddr:x} is not inside a file-backed PT_LOAD segment")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("input")
    ap.add_argument("patch_blob", help="32-byte AArch64 patch assembled for VA 0x1ce04")
    ap.add_argument("output")
    args = ap.parse_args()

    src = Path(args.input)
    patch = Path(args.patch_blob)
    dst = Path(args.output)

    actual = sha256(src)
    if actual != EXPECTED_SHA256:
        raise SystemExit(
            f"Refusing to patch unexpected binary.\n"
            f"Expected: {EXPECTED_SHA256}\nActual:   {actual}"
        )

    blob = patch.read_bytes()
    if len(blob) != PATCH_SIZE:
        raise SystemExit(f"Patch blob must be exactly {PATCH_SIZE} bytes, got {len(blob)}")

    data = bytearray(src.read_bytes())
    file_off = vaddr_to_offset(data, PATCH_VADDR)

    # The original block contains the 1x/2x conditional width/height selection.
    original = bytes(data[file_off:file_off + PATCH_SIZE])
    if len(original) != PATCH_SIZE:
        raise SystemExit("Patch range falls outside file")

    data[file_off:file_off + PATCH_SIZE] = blob
    dst.write_bytes(data)

    print(f"Input SHA-256 : {actual}")
    print(f"Patch VA      : 0x{PATCH_VADDR:x}")
    print(f"Patch file off: 0x{file_off:x}")
    print(f"Original bytes: {original.hex()}")
    print(f"Patched bytes : {blob.hex()}")
    print(f"Output SHA-256: {sha256(dst)}")

if __name__ == "__main__":
    main()
