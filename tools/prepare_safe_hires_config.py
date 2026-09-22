#!/usr/bin/env python3
from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: prepare_safe_hires_config.py <h.smali>")

p = Path(sys.argv[1])
s = p.read_text()

def replace_once(old: str, new: str, label: str):
    global s
    if old not in s:
        raise SystemExit(f"missing anchor: {label}")
    if s.count(old) != 1:
        raise SystemExit(f"anchor not unique: {label}")
    s = s.replace(old, new, 1)

replace_once(
    ".field public static D0:Z = false\n",
    ".field public static D0:Z = false\n\n.field public static Hires3DScale:I = 0x1\n",
    "global scale field",
)
replace_once(
    ".field public static V0:Z = false\n",
    ".field public static V0:Z = false\n\n.field public static Hires3DScaleGame:I = 0x1\n",
    "game scale field",
)

sig = ".method public static n()J"
start = s.find(sig)
if start < 0:
    raise SystemExit("n() method missing")
end = s.find(".end method", start)
if end < 0:
    raise SystemExit("n() end missing")

method = s[start:end]
old = """    :cond_12
    return-wide v0
"""
new = """    :cond_12
    # Minimal live internal-resolution transport.
    # Default Hires3DScale=1 emits zero in bits 51-52, so original config is unchanged.
    sget v2, Lf0/h;->Hires3DScale:I

    add-int/lit8 v2, v2, -0x1

    and-int/lit8 v2, v2, 0x3

    int-to-long v2, v2

    const/16 v4, 0x33

    shl-long/2addr v2, v4

    or-long/2addr v0, v2

    return-wide v0
"""
if old not in method:
    raise SystemExit("n() return anchor missing")
method = method.replace(old, new, 1)
s = s[:start] + method + s[end:]

p.write_text(s)
print("Prepared safe minimal HiRes config transport.")
