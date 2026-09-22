.text
// renderFrame source expander.
// Top entry expects:
//   x9  = source framebuffer
//   w26 = scale index (0..3)
//   x27 = renderer globals
// Returns x9 as upload source and w5 as upload height.
top_entry:
mov x18, x30
mov x0, x9
mov w1, w26
bl common_expand
mov x9, x0
mov x30, x18
ret

// Bottom entry expects x8/w24 and returns x8/w5.
.word 0xfeed3001
bottom_entry:
mov x18, x30
mov x0, x8
mov w1, w24
bl common_expand
mov x8, x0
mov w0, #0xde1
mov x30, x18
ret

common_expand:
add w2, w1, #1
add w5, w2, w2, lsl #1
lsl w5, w5, #6          // height = 192 * scale
cmp w2, #3
b.lo passthrough

// Scratch buffer lives after the normal 12 MiB renderer allocation.
ldr x4, [x27]
mov x5, #0xc00000
add x4, x4, x5
mov x15, x4

ldr w3, [x27, #0x95c]
cmp w3, #0x10
b.eq pixels16

// ---------------- RGBA8888 / 32-bit ----------------
cmp w2, #3
b.eq s3_32

// 4x: legacy 512x384 -> 1024x768.
mov x10, x0
mov x11, x4
mov w12, wzr
s4_32_row:
mov x13, x10
add x14, x10, #0x800
mov x15, x11
add x16, x11, #0x1, lsl #12
add x17, x11, #0x2, lsl #12
add x3,  x11, #0x3, lsl #12
mov w8, wzr
s4_32_pixel:
ldr w1, [x13], #4
ldr w2, [x14], #4
str w1, [x15], #4
str w1, [x15], #4
str w1, [x16], #4
str w1, [x16], #4
str w2, [x17], #4
str w2, [x17], #4
str w2, [x3], #4
str w2, [x3], #4
add w8, w8, #1
cmp w8, #0x200
b.ne s4_32_pixel
add x10, x10, #0x1, lsl #12
add x11, x11, #0x4, lsl #12
add w12, w12, #1
cmp w12, #0xc0
b.ne s4_32_row
ldr x0, [x27]
mov x1, #0xc00000
add x0, x0, x1
ret

s3_32:
mov x10, x0
mov x11, x4
mov w12, wzr
s3_32_row:
mov x13, x10
add x14, x10, #0x800
mov x15, x11
add x16, x11, #0xc00
add x17, x11, #0x1, lsl #12
add x17, x17, #0x800
mov w8, wzr
s3_32_pixel:
ldp w1, w2, [x13], #8
ldp w3, w4, [x14], #8
str w1, [x15], #4
str w1, [x15], #4
str w2, [x15], #4
str w1, [x16], #4
str w1, [x16], #4
str w2, [x16], #4
str w3, [x17], #4
str w3, [x17], #4
str w4, [x17], #4
add w8, w8, #1
cmp w8, #0x100
b.ne s3_32_pixel
add x10, x10, #0x1, lsl #12
add x11, x11, #0x2, lsl #12
add x11, x11, #0x400
add w12, w12, #1
cmp w12, #0xc0
b.ne s3_32_row
ldr x0, [x27]
mov x1, #0xc00000
add x0, x0, x1
ret

// ---------------- RGB565 / 16-bit ----------------
pixels16:
cmp w2, #3
b.eq s3_16

// 4x: 512x384 -> 1024x768, 2 bytes/pixel.
mov x10, x0
mov x11, x4
mov w12, wzr
s4_16_row:
mov x13, x10
add x14, x10, #0x400
mov x15, x11
add x16, x11, #0x800
add x17, x11, #0x1, lsl #12
add x3,  x11, #0x1, lsl #12
add x3,  x3, #0x800
mov w8, wzr
s4_16_pixel:
ldrh w1, [x13], #2
ldrh w2, [x14], #2
strh w1, [x15], #2
strh w1, [x15], #2
strh w1, [x16], #2
strh w1, [x16], #2
strh w2, [x17], #2
strh w2, [x17], #2
strh w2, [x3], #2
strh w2, [x3], #2
add w8, w8, #1
cmp w8, #0x200
b.ne s4_16_pixel
add x10, x10, #0x800
add x11, x11, #0x2, lsl #12
add w12, w12, #1
cmp w12, #0xc0
b.ne s4_16_row
ldr x0, [x27]
mov x1, #0xc00000
add x0, x0, x1
ret

s3_16:
mov x10, x0
mov x11, x4
mov w12, wzr
s3_16_row:
mov x13, x10
add x14, x10, #0x400
mov x15, x11
add x16, x11, #0x600
add x17, x11, #0xc00
mov w8, wzr
s3_16_pixel:
ldrh w1, [x13], #2
ldrh w2, [x13], #2
ldrh w3, [x14], #2
ldrh w4, [x14], #2
strh w1, [x15], #2
strh w1, [x15], #2
strh w2, [x15], #2
strh w1, [x16], #2
strh w1, [x16], #2
strh w2, [x16], #2
strh w3, [x17], #2
strh w3, [x17], #2
strh w4, [x17], #2
add w8, w8, #1
cmp w8, #0x100
b.ne s3_16_pixel
add x10, x10, #0x800
add x11, x11, #0x1, lsl #12
add x11, x11, #0x200
add w12, w12, #1
cmp w12, #0xc0
b.ne s3_16_row
ldr x0, [x27]
mov x1, #0xc00000
add x0, x0, x1
ret

passthrough:
ret
