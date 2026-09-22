#!/usr/bin/env python3
import struct, sys
from pathlib import Path

if len(sys.argv) != 4:
    raise SystemExit("usage: patch_fxrender_expander.py <input.so> <wrapper.bin> <output.so>")

src=Path(sys.argv[1]); wrapper_path=Path(sys.argv[2]); dst=Path(sys.argv[3])
data=bytearray(src.read_bytes()); wrapper=bytearray(wrapper_path.read_bytes())

BASE=0xf0900
COMMON=0xf063c
GL_ACTIVE=0x15b60
CALL1=0x1d298
CALL2=0x1d320
CFG_PAGE=0x14c000

def u32(buf,off): return struct.unpack_from("<I",buf,off)[0]
def w32(buf,off,v): struct.pack_into("<I",buf,off,v & 0xffffffff)
def branch(pc,target,link=True):
    d=target-pc
    if d & 3: raise SystemExit("unaligned branch")
    imm=d//4
    if not (-(1<<25)<=imm<(1<<25)): raise SystemExit("branch out of range")
    return (0x94000000 if link else 0x14000000)|(imm&0x03ffffff)
def adrp(rd,pc,target):
    imm=((target&~0xfff)-(pc&~0xfff))>>12
    if not (-(1<<20)<=imm<(1<<20)): raise SystemExit("ADRP out of range")
    v=imm&((1<<21)-1)
    return 0x90000000|((v&3)<<29)|(((v>>2)&0x7ffff)<<5)|rd
def find(marker):
    raw=struct.pack("<I",marker); hits=[]; p=0
    while True:
        p=wrapper.find(raw,p)
        if p<0: break
        hits.append(p); p+=4
    if len(hits)!=1: raise SystemExit(f"marker 0x{marker:x}: {hits}")
    return hits[0]

# Both sites are the original glActiveTexture calls.
if u32(data,CALL1) != 0x97ffe232:
    raise SystemExit(f"unexpected fxRender call1: 0x{u32(data,CALL1):08x}")
if u32(data,CALL2) != 0x97ffe210:
    raise SystemExit(f"unexpected fxRender call2: 0x{u32(data,CALL2):08x}")

if any(data[BASE:BASE+len(wrapper)+32]):
    raise SystemExit("fx wrapper cave is not empty")

# Append a scale helper:
#   adrp x9, packed-config-page
#   ldr  x9, [x9,#0x468]
#   lsr  x1, x9,#51
#   and  w1,w1,#3
#   ret
scale_helper_off=(len(wrapper)+3)&~3
while len(wrapper)<scale_helper_off:
    wrapper.append(0)
scale_helper_va=BASE+scale_helper_off
wrapper += struct.pack("<I",adrp(9,scale_helper_va,CFG_PAGE))
wrapper += struct.pack("<I",0xf9423529)
wrapper += struct.pack("<I",0xd373fd21)
wrapper += struct.pack("<I",0x12000421)
wrapper += struct.pack("<I",0xd65f03c0)

for marker in (0xfeed4001,0xfeed4005):
    o=find(marker); w32(wrapper,o,branch(BASE+o,scale_helper_va,True))
for marker in (0xfeed4002,0xfeed4006):
    o=find(marker); w32(wrapper,o,branch(BASE+o,COMMON,True))
for marker in (0xfeed4003,0xfeed4007):
    o=find(marker); w32(wrapper,o,branch(BASE+o,GL_ACTIVE,True))

m=find(0xfeed4004)
second=BASE+m+4
w32(wrapper,m,0xd503201f)

data[BASE:BASE+len(wrapper)]=wrapper
w32(data,CALL1,branch(CALL1,BASE,True))
w32(data,CALL2,branch(CALL2,second,True))

dst.write_bytes(data)
print(f"fxRender expansion installed: 0x{CALL1:x}->0x{BASE:x}, 0x{CALL2:x}->0x{second:x}")
print(f"scale helper=0x{scale_helper_va:x}, common expander=0x{COMMON:x}")
