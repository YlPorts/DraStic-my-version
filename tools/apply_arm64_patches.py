#!/usr/bin/env python3
import argparse
import hashlib
import struct
from pathlib import Path

ORIGINAL_SHA256 = "3b27eee0c480df818e5adfde227f4b92ce57bc468562f7f7f079a121b8dcd902"

def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def vaddr_to_offset(data: bytes, vaddr: int) -> int:
    if data[:4] != b"\x7fELF" or data[4] != 2 or data[5] != 1:
        raise ValueError("Expected ELF64 little-endian")
    e_phoff = struct.unpack_from("<Q", data, 0x20)[0]
    e_phentsize = struct.unpack_from("<H", data, 0x36)[0]
    e_phnum = struct.unpack_from("<H", data, 0x38)[0]
    for i in range(e_phnum):
        off = e_phoff + i * e_phentsize
        p_type, _ = struct.unpack_from("<II", data, off)
        p_offset, p_vaddr, _, p_filesz, _, _ = struct.unpack_from("<QQQQQQ", data, off + 8)
        if p_type == 1 and p_vaddr <= vaddr < p_vaddr + p_filesz:
            return p_offset + (vaddr - p_vaddr)
    raise ValueError(f"VA 0x{vaddr:x} is not file-backed")

def parse_patch(spec: str):
    try:
        addr, filename = spec.split(":", 1)
        return int(addr, 0), Path(filename)
    except Exception as e:
        raise argparse.ArgumentTypeError("patch format must be VA:file") from e

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("input")
    ap.add_argument("output")
    ap.add_argument("--patch", action="append", default=[], type=parse_patch,
                    help="Patch blob in VA:file form; may be repeated")
    ap.add_argument("--expected-sha256", default=ORIGINAL_SHA256)
    args = ap.parse_args()

    src = Path(args.input)
    dst = Path(args.output)
    data = bytearray(src.read_bytes())
    actual = sha256_bytes(data)
    if actual != args.expected_sha256:
        raise SystemExit(
            "Refusing to patch unexpected input.\n"
            f"Expected: {args.expected_sha256}\nActual:   {actual}"
        )

    occupied = []
    print(f"Input SHA-256: {actual}")
    for va, blob_path in args.patch:
        blob = blob_path.read_bytes()
        if not blob:
            raise SystemExit(f"Empty patch blob: {blob_path}")
        off = vaddr_to_offset(data, va)
        end = off + len(blob)
        for old_start, old_end, old_va in occupied:
            if max(off, old_start) < min(end, old_end):
                raise SystemExit(
                    f"Patch overlap: VA 0x{va:x} overlaps patch at VA 0x{old_va:x}"
                )
        occupied.append((off, end, va))
        before = bytes(data[off:end])
        data[off:end] = blob
        print(
            f"VA 0x{va:x} -> file 0x{off:x}, {len(blob)} bytes\n"
            f"  before: {before.hex()}\n"
            f"  after : {blob.hex()}"
        )

    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_bytes(data)
    print(f"Output SHA-256: {sha256_file(dst)}")

if __name__ == "__main__":
    main()
