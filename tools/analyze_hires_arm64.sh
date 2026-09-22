#!/usr/bin/env bash
set -euo pipefail

BIN="${1:-universal/lib/arm64-v8a/libdrastic_arm64.so}"
OUT="${2:-analysis/native_hires_arm64.txt}"
mkdir -p "$(dirname "$OUT")"

OBJDUMP="${OBJDUMP:-aarch64-linux-gnu-objdump}"
READELF="${READELF:-aarch64-linux-gnu-readelf}"
NM="${NM:-aarch64-linux-gnu-nm}"

if [[ ! -f "$BIN" ]]; then
  echo "Binary not found: $BIN" >&2
  exit 1
fi

TMP_DIS="$(mktemp)"
trap 'rm -f "$TMP_DIS"' EXIT

"$OBJDUMP" -d "$BIN" > "$TMP_DIS"

{
  echo "# DraStic ARM64 native HiRes3D analysis"
  echo
  echo "Binary: $BIN"
  echo "SHA-256: $(sha256sum "$BIN" | awk '{print $1}')"
  echo "Generated (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
  echo "## ELF header"
  "$READELF" -h "$BIN" || true
  echo
  echo "## JNI / graphics dynamic symbols"
  "$NM" -D "$BIN" 2>/dev/null | grep -Ei 'DraSticJNI|applyConfig|renderFrame|updateFrame|gl[A-Z]|egl[A-Z]|framebuffer|renderbuffer|texture|viewport|scissor' || true
  echo
  echo "## Imported OpenGL/EGL functions"
  "$READELF" -Ws "$BIN" 2>/dev/null | grep -Ei 'UND.*(gl|egl)(TexImage|TexStorage|Framebuffer|Renderbuffer|Viewport|Scissor|Blit|Draw|Bind|Clear|ReadPixels|ActiveTexture|Uniform|UseProgram)' || true
  echo
  echo "## Interesting strings"
  strings -a "$BIN" | grep -Ei 'hires|high.?res|render|framebuffer|renderbuffer|resolution|shader|texture|OpenGL|GLES|viewport|scissor' | head -n 300 || true
  echo
  echo "## applyConfig disassembly"
  python3 - "$TMP_DIS" <<'PY'
import re, sys
p = sys.argv[1]
lines = open(p, errors='replace').read().splitlines()
needle = re.compile(r'<Java_com_dsemu_drastic_DraSticJNI_applyConfig[^>]*>:')
start = next((i for i,l in enumerate(lines) if needle.search(l)), None)
if start is None:
    for n in ('applyConfig', 'Java_com_dsemu_drastic_DraSticJNI_applyConfig'):
        hits=[(i,l) for i,l in enumerate(lines) if n in l]
        if hits:
            print("Symbol label not found; references:")
            for i,l in hits[:40]:
                print(f"{i+1}: {l}")
            break
    else:
        print("applyConfig symbol not found in disassembly.")
else:
    end = len(lines)
    sym = re.compile(r'^[0-9a-fA-F]+ <[^>]+>:$')
    for i in range(start+1, len(lines)):
        if sym.match(lines[i].strip()):
            end = i
            break
    for l in lines[start:end]:
        print(l)
PY
  echo
  echo "## Bit tests around config bit 41 (0x20000000000 / Hires3D)"
  python3 - "$TMP_DIS" <<'PY'
import re, sys
lines=open(sys.argv[1], errors='replace').read().splitlines()
patterns=[
    re.compile(r'\b(tbz|tbnz)\b.*(?:#0x29|#41)\b',re.I),
    re.compile(r'\b(?:and|ands|tst)\b.*(?:0x20000000000|#0x20000000000)',re.I),
]
hits=[]
for i,l in enumerate(lines):
    if any(p.search(l) for p in patterns):
        hits.append(i)
if not hits:
    print("No direct bit-41 test found; compiler may extract/shift the config field differently.")
for n,i in enumerate(hits[:80],1):
    print(f"\n--- hit {n}, disassembly line {i+1} ---")
    for l in lines[max(0,i-8):min(len(lines),i+13)]:
        print(l)
PY
  echo
  echo "## Native-resolution / HiRes-sized immediates"
  python3 - "$TMP_DIS" <<'PY'
import re, sys
lines=open(sys.argv[1], errors='replace').read().splitlines()
# DS native 256x192 and classic 2x HiRes 512x384.
pat = re.compile(r'(?<![0-9a-f])(?:#0x100\b|#0xc0\b|#0x200\b|#0x180\b|#256\b|#192\b|#512\b|#384\b)', re.I)
hits=[i for i,l in enumerate(lines) if pat.search(l)]
print(f"Found {len(hits)} matching instructions.")
for n,i in enumerate(hits[:160],1):
    print(f"\n--- hit {n}, disassembly line {i+1} ---")
    for l in lines[max(0,i-4):min(len(lines),i+7)]:
        print(l)
PY
  echo
  echo
  echo "## Config high-word bit 9 tests (Hires3D bit 41)"
  python3 - "$TMP_DIS" <<'PY'
import re, sys
lines=open(sys.argv[1], errors='replace').read().splitlines()
pat=re.compile(r'\b(tbz|tbnz)\b\s+w\d+,\s*#9\b', re.I)
hits=[i for i,l in enumerate(lines) if pat.search(l)]
print(f"Found {len(hits)} bit-9 tests.")
for n,i in enumerate(hits[:120],1):
    print(f"\n--- bit9 hit {n}, disassembly line {i+1} ---")
    for l in lines[max(0,i-12):min(len(lines),i+17)]:
        print(l)
PY
  echo
  echo "## Writes/reads of candidate render size fields +348 / +352"
  python3 - "$TMP_DIS" <<'PY'
import re, sys
lines=open(sys.argv[1], errors='replace').read().splitlines()
pat=re.compile(r'\[(?:x|w)\d+,\s*#(?:348|352)\]')
hits=[i for i,l in enumerate(lines) if pat.search(l)]
print(f"Found {len(hits)} accesses.")
for n,i in enumerate(hits[:180],1):
    print(f"\n--- size-field hit {n}, disassembly line {i+1} ---")
    for l in lines[max(0,i-14):min(len(lines),i+19)]:
        print(l)
PY
  echo
  echo "## Functions around applyConfig helper targets"
  python3 - "$TMP_DIS" <<'PY'
import re, sys
lines=open(sys.argv[1], errors='replace').read().splitlines()
targets=(0x1cbc0,0x1d728,0x1f600,0x20500)
addr_re=re.compile(r'^\s*([0-9a-fA-F]+):')
for target in targets:
    nearest=None
    for i,l in enumerate(lines):
        m=addr_re.match(l)
        if m:
            a=int(m.group(1),16)
            if a>=target:
                nearest=i
                break
    print(f"\n=== around 0x{target:x} ===")
    if nearest is None:
        print("not found")
        continue
    for l in lines[max(0,nearest-30):min(len(lines),nearest+180)]:
        print(l)
PY
  echo
  echo
  echo "## Calls to native HiRes size setter at 0x1cde4"
  python3 - "$TMP_DIS" <<'PY'
import re, sys
lines=open(sys.argv[1], errors='replace').read().splitlines()
pat=re.compile(r'\bbl\s+1cde4\b', re.I)
hits=[i for i,l in enumerate(lines) if pat.search(l)]
print(f"Found {len(hits)} calls.")
for n,i in enumerate(hits,1):
    print(f"\n--- call {n}, disassembly line {i+1} ---")
    for l in lines[max(0,i-35):min(len(lines),i+25)]:
        print(l)
PY
  echo
  echo "## Accesses to stored packed config at global offset +1128"
  python3 - "$TMP_DIS" <<'PY'
import re, sys
lines=open(sys.argv[1], errors='replace').read().splitlines()
pat=re.compile(r'\[[xw]\d+,\s*#1128\]')
hits=[i for i,l in enumerate(lines) if pat.search(l)]
print(f"Found {len(hits)} accesses.")
for n,i in enumerate(hits[:100],1):
    print(f"\n--- config access {n}, disassembly line {i+1} ---")
    for l in lines[max(0,i-22):min(len(lines),i+28)]:
        print(l)
PY
  echo
  echo "## ELF program/section mapping for patch addresses"
  aarch64-linux-gnu-readelf -lW "$BIN" || true
  aarch64-linux-gnu-readelf -SW "$BIN" | grep -E '(^| )\.(text|plt|rodata|data|bss)( |$)' || true
  echo
  echo
  echo "## Packed-config decoder 0x17c58"
  "$OBJDUMP" -d --start-address=0x17c58 --stop-address=0x17df4 "$BIN" || true
  echo
  echo "## Calls/references near framebuffer-related imports"
  python3 - "$TMP_DIS" <<'PY'
import re, sys
lines=open(sys.argv[1], errors='replace').read().splitlines()
pat = re.compile(r'gl(?:TexImage2D|TexStorage2D|RenderbufferStorage|FramebufferTexture2D|Viewport|Scissor|BlitFramebuffer)@plt', re.I)
hits=[i for i,l in enumerate(lines) if pat.search(l)]
print(f"Found {len(hits)} graphics-call references.")
for n,i in enumerate(hits[:120],1):
    print(f"\n--- graphics hit {n}, disassembly line {i+1} ---")
    for l in lines[max(0,i-10):min(len(lines),i+11)]:
        print(l)
PY
} > "$OUT"

echo "Wrote $OUT"
