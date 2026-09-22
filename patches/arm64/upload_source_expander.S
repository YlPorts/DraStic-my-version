.text
// Safe upload-source expander for DraStic ARM64.
// Covers both renderFrame and fxRender.
//
// Input to common_expand:
//   x0 = legacy 2x linear source (512x384)
//   w1 = requested scale factor 1..4
// Output:
//   x0 = upload source (original for <=2x, scratch for 3x/4x)
//
// Scratch starts at renderer allocation + 0xC00000.
// The O build extends that allocation from 12 MiB to 15 MiB.

.word 0xfeed4101
render_top_entry:
stp x8, x30, [sp, #-16]!
mov x0, x9
add w1, w26, #1
bl common_expand
mov x9, x0
ldp x8, x30, [sp], #16
add w5, w8, w8, lsl #1
lsl w5, w5, #6
ret

.word 0xfeed4102
render_bottom_entry:
str x30, [sp, #-16]!
umaddl x0, w21, w8, x23
add w1, w24, #1
bl common_expand
mov x8, x0
add w5, w24, #1
add w5, w5, w5, lsl #1
lsl w5, w5, #6
ldr x30, [sp], #16
ret

.word 0xfeed4103
fx_top_entry:
str x30, [sp, #-16]!
umaddl x0, w9, w8, x13
lsr w1, w23, #8
bl common_expand
mov x25, x0
mov x0, x28
ldr x30, [sp], #16
ret

.word 0xfeed4104
fx_bottom_entry:
stp x8, x30, [sp, #-16]!
madd x0, x10, x9, x11
mov w1, w8
bl common_expand
mov x20, x0
ldp x8, x30, [sp], #16
ret

common_expand:
cmp w1, #3
b.hs expand_go
ret

expand_go:
mov w12, w1
.word 0xfeed4105          // patched to: adrp x14, renderer-global page
add x14, x14, #0x1f8
ldr w3, [x14, #0x95c]
ldr x4, [x14]
mov x5, #0xc00000
add x4, x4, x5

cmp w3, #0x10
b.eq pixels16

// ---------- 32-bit RGBA ----------
cmp w12, #3
b.eq s3_32

// 4x: 512x384 -> 1024x768
mov x10, x0
mov x11, x4
mov w9, wzr
s4_32_row:
mov x13, x10
add x14, x10, #0x800
mov x15, x11
add x16, x11, #0x1, lsl #12
add x17, x11, #0x2, lsl #12
add x5,  x11, #0x3, lsl #12
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
str w2, [x5], #4
str w2, [x5], #4
add w8, w8, #1
cmp w8, #0x200
b.ne s4_32_pixel
add x10, x10, #0x1, lsl #12
add x11, x11, #0x4, lsl #12
add w9, w9, #1
cmp w9, #0xc0
b.ne s4_32_row
mov x0, x4
ret

s3_32:
mov x10, x0
mov x11, x4
mov w9, wzr
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
ldp w3, w5, [x14], #8
str w1, [x15], #4
str w1, [x15], #4
str w2, [x15], #4
str w1, [x16], #4
str w1, [x16], #4
str w2, [x16], #4
str w3, [x17], #4
str w3, [x17], #4
str w5, [x17], #4
add w8, w8, #1
cmp w8, #0x100
b.ne s3_32_pixel
add x10, x10, #0x1, lsl #12
add x11, x11, #0x2, lsl #12
add x11, x11, #0x400
add w9, w9, #1
cmp w9, #0xc0
b.ne s3_32_row
mov x0, x4
ret

// ---------- 16-bit RGB ----------
pixels16:
cmp w12, #3
b.eq s3_16

// 4x: 512x384 -> 1024x768
mov x10, x0
mov x11, x4
mov w9, wzr
s4_16_row:
mov x13, x10
add x14, x10, #0x400
mov x15, x11
add x16, x11, #0x800
add x17, x11, #0x1, lsl #12
add x5,  x11, #0x1, lsl #12
add x5,  x5, #0x800
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
strh w2, [x5], #2
strh w2, [x5], #2
add w8, w8, #1
cmp w8, #0x200
b.ne s4_16_pixel
add x10, x10, #0x800
add x11, x11, #0x2, lsl #12
add w9, w9, #1
cmp w9, #0xc0
b.ne s4_16_row
mov x0, x4
ret

s3_16:
mov x10, x0
mov x11, x4
mov w9, wzr
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
ldrh w5, [x14], #2
strh w1, [x15], #2
strh w1, [x15], #2
strh w2, [x15], #2
strh w1, [x16], #2
strh w1, [x16], #2
strh w2, [x16], #2
strh w3, [x17], #2
strh w3, [x17], #2
strh w5, [x17], #2
add w8, w8, #1
cmp w8, #0x100
b.ne s3_16_pixel
add x10, x10, #0x800
add x11, x11, #0x1, lsl #12
add x11, x11, #0x200
add w9, w9, #1
cmp w9, #0xc0
b.ne s3_16_row
mov x0, x4
ret
