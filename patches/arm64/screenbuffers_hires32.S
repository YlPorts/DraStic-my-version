.text
// Generic HiRes 32-bit source -> 256x192 RGBA output.
// x24/x0 = native screen sources, x22/x23 = Java output buffers, x25 = packed config.
ubfx x1, x25, #51, #2
add w1, w1, #1
lsl w14, w1, #2
mul w15, w1, w1
lsl w15, w15, #10
mov w8, #0
mov x11, x24
mov x12, x0
mov x9, x22
mov x10, x23
row32:
mov w13, #0
mov x3, x11
mov x4, x12
mov x5, x9
mov x6, x10
pixel32:
ldr w7, [x3]
ldr w16, [x4]
and w17, w7, #0xff00
bfi w17, w7, #16, #16
bfxil w17, w7, #16, #8
orr w17, w17, #0xff000000
and w2, w16, #0xff00
bfi w2, w16, #16, #16
bfxil w2, w16, #16, #8
orr w2, w2, #0xff000000
str w17, [x5], #4
str w2, [x6], #4
add x3, x3, x14
add x4, x4, x14
add w13, w13, #1
cmp w13, #0x100
b.ne pixel32
add x11, x11, x15
add x12, x12, x15
add x9, x9, #0x400
add x10, x10, #0x400
add w8, w8, #1
cmp w8, #0xc0
b.ne row32
