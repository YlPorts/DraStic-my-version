.text
// Generic HiRes 16-bit source -> 256x192 RGBA output.
// x24/x0 = native screen sources, x22/x23 = Java output buffers, x25 = packed config.
ubfx x1, x25, #51, #2
add w1, w1, #1
lsl w14, w1, #1
mul w15, w1, w1
lsl w15, w15, #9
mov w8, #0
mov x11, x24
mov x12, x0
mov x9, x22
mov x10, x23
row16:
mov w13, #0
mov x3, x11
mov x4, x12
mov x5, x9
mov x6, x10
pixel16:
ldrh w7, [x3]
ldrh w2, [x4]
lsl w17, w7, #5
and w17, w17, #0xfc00
lsr w16, w7, #11
bfi w17, w7, #3, #5
bfi w17, w16, #19, #5
orr w17, w17, #0xff000000
lsl w1, w2, #5
and w1, w1, #0xfc00
lsr w16, w2, #11
bfi w1, w2, #3, #5
bfi w1, w16, #19, #5
orr w1, w1, #0xff000000
str w17, [x5], #4
str w1, [x6], #4
add x3, x3, x14
add x4, x4, x14
add w13, w13, #1
cmp w13, #0x100
b.ne pixel16
add x11, x11, x15
add x12, x12, x15
add x9, x9, #0x400
add x10, x10, #0x400
add w8, w8, #1
cmp w8, #0xc0
b.ne row16
