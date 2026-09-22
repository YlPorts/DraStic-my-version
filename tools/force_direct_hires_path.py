#!/usr/bin/env python3
from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: force_direct_hires_path.py <DraSticGlView$j.smali>")

p=Path(sys.argv[1])
s=p.read_text()

old='''    invoke-static {v11}, Lcom/dsemu/drastic/DraSticGlView;->D(Lcom/dsemu/drastic/DraSticGlView;)Z

    move-result v11

    if-eqz v11, :cond_11
'''
new='''    invoke-static {v11}, Lcom/dsemu/drastic/DraSticGlView;->D(Lcom/dsemu/drastic/DraSticGlView;)Z

    move-result v11

    # 3x/4x diagnostic/fallback: bypass the FX chain and use the direct
    # texture path. 1x/2x preserve DraStic's original behavior.
    sget v12, Lf0/h;->Hires3DScale:I

    const/4 v13, 0x3

    if-lt v12, v13, :hires_keep_original_render_path

    const/4 v11, 0x1

    :hires_keep_original_render_path
    if-eqz v11, :cond_11
'''

if s.count(old) != 1:
    raise SystemExit(f"render path anchor count={s.count(old)}")
s=s.replace(old,new,1)
p.write_text(s)
print("Forced direct renderFrame path for internal scale >= 3x.")
