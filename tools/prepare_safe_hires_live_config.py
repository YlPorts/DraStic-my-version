#!/usr/bin/env python3
from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: prepare_safe_hires_live_config.py <h.smali>")

p=Path(sys.argv[1])
s=p.read_text()

def once(old,new,label):
    global s
    if s.count(old)!=1:
        raise SystemExit(f"{label}: expected one anchor, got {s.count(old)}")
    s=s.replace(old,new,1)

once(
    ".field public static D0:Z = false\n",
    ".field public static D0:Z = false\n\n.field public static Hires3DScale:I = 0x1\n",
    "global scale field"
)
once(
    ".field public static V0:Z = false\n",
    ".field public static V0:Z = false\n\n.field public static Hires3DScaleGame:I = 0x1\n",
    "effective scale field"
)

sig=".method public static n()J"
start=s.find(sig)
end=s.find(".end method",start)
if start<0 or end<0:
    raise SystemExit("n() method missing")

m=s[start:end]
old="""    :cond_12
    return-wide v0
"""
new="""    :cond_12
    # Minimal live scale transport only. No startup preference changes.
    sget v2, Lf0/h;->Hires3DScale:I

    add-int/lit8 v2, v2, -0x1

    and-int/lit8 v2, v2, 0x3

    int-to-long v2, v2

    const/16 v4, 0x33

    shl-long/2addr v2, v4

    or-long/2addr v0, v2

    return-wide v0
"""
if old not in m:
    raise SystemExit("n() return anchor missing")
m=m.replace(old,new,1)
s=s[:start]+m+s[end:]
p.write_text(s)
print("Prepared safe live HiRes config without startup persistence.")
