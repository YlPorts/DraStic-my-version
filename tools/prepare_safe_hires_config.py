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

# Persist the scale next to the legacy _Hires3D boolean.
replace_once(
    '''    const-string v2, "_Hires3D"

    sget-boolean v3, Lf0/h;->D0:Z

    invoke-interface {v0, v2, v3}, Landroid/content/SharedPreferences$Editor;->putBoolean(Ljava/lang/String;Z)Landroid/content/SharedPreferences$Editor;
''',
    '''    const-string v2, "_Hires3D"

    sget-boolean v3, Lf0/h;->D0:Z

    invoke-interface {v0, v2, v3}, Landroid/content/SharedPreferences$Editor;->putBoolean(Ljava/lang/String;Z)Landroid/content/SharedPreferences$Editor;

    const-string v2, "_Hires3DScale"

    sget v3, Lf0/h;->Hires3DScale:I

    invoke-interface {v0, v2, v3}, Landroid/content/SharedPreferences$Editor;->putInt(Ljava/lang/String;I)Landroid/content/SharedPreferences$Editor;
''',
    "save global scale",
)

# Load the integer scale with backward compatibility: old HiRes=true means 2x.
replace_once(
    '''    const-string v0, "_Hires3D"

    invoke-interface {v2, v0, v1}, Landroid/content/SharedPreferences;->getBoolean(Ljava/lang/String;Z)Z

    move-result v0

    sput-boolean v0, Lf0/h;->D0:Z
''',
    '''    const-string v0, "_Hires3D"

    invoke-interface {v2, v0, v1}, Landroid/content/SharedPreferences;->getBoolean(Ljava/lang/String;Z)Z

    move-result v0

    sput-boolean v0, Lf0/h;->D0:Z

    const-string v0, "_Hires3DScale"

    sget-boolean v3, Lf0/h;->D0:Z

    if-eqz v3, :hires_scale_default_1x

    const/4 v3, 0x2

    goto :hires_scale_default_ready

    :hires_scale_default_1x
    const/4 v3, 0x1

    :hires_scale_default_ready
    invoke-interface {v2, v0, v3}, Landroid/content/SharedPreferences;->getInt(Ljava/lang/String;I)I

    move-result v0

    const/4 v3, 0x1

    if-ge v0, v3, :hires_scale_min_ok

    move v0, v3

    :hires_scale_min_ok
    const/4 v3, 0x4

    if-le v0, v3, :hires_scale_max_ok

    move v0, v3

    :hires_scale_max_ok
    sput v0, Lf0/h;->Hires3DScale:I

    sput v0, Lf0/h;->Hires3DScaleGame:I

    const/4 v3, 0x1

    if-le v0, v3, :hires_scale_loaded_off

    const/4 v3, 0x1

    sput-boolean v3, Lf0/h;->D0:Z

    sput-boolean v3, Lf0/h;->V0:Z

    goto :hires_scale_loaded_done

    :hires_scale_loaded_off
    const/4 v3, 0x0

    sput-boolean v3, Lf0/h;->D0:Z

    sput-boolean v3, Lf0/h;->V0:Z

    :hires_scale_loaded_done
''',
    "load global scale",
)

# Keep effective per-game/effective scale synchronized when global settings are copied.
replace_once(
    '''    sget-boolean v0, Lf0/h;->D0:Z

    sput-boolean v0, Lf0/h;->V0:Z

    sget v0, Lf0/h;->s1:I
''',
    '''    sget-boolean v0, Lf0/h;->D0:Z

    sput-boolean v0, Lf0/h;->V0:Z

    sget v0, Lf0/h;->Hires3DScale:I

    sput v0, Lf0/h;->Hires3DScaleGame:I

    sget v0, Lf0/h;->s1:I
''',
    "copy global scale to effective scale",
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
    sget v2, Lf0/h;->Hires3DScaleGame:I

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
