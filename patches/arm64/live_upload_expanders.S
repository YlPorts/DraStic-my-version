.text
// Combined diagnostic framebuffer expander for the actual live upload paths.
// For scale 3/4 it expands the legacy 512x384 image into contiguous
// 768x576 / 1024x768 scratch memory before glTexSubImage2D.

// Marker -> renderFrame top entry.
.word 0xfeed5000
rf_top:
sub sp, sp, #0x20
stp x6, x7, [sp]
str x30, [sp, #0x10]
mov x0, x9
add w1, w26, #1
bl expand_common
mov x9, x0
add w8, w26, #1
add w5, w8, w8, lsl #1
lsl w5, w5, #6
ldr x30, [sp, #0x10]
ldp x6, x7, [sp]
add sp, sp, #0x20
ret

// Marker -> renderFrame bottom entry. Source x8 is already computed here.
.word 0xfeed5001
rf_bottom:
sub sp, sp, #0x30
stp x4, x5, [sp]
stp x6, x7, [sp, #0x10]
str x30, [sp, #0x20]
mov x0, x8
add w1, w24, #1
bl expand_common
mov x8, x0
mov w0, #0xde1
ldr x30, [sp, #0x20]
ldp x6, x7, [sp, #0x10]
ldp x4, x5, [sp]
add sp, sp, #0x30
ret

// Marker -> fxRender first upload entry.
.word 0xfeed5002
fx_first:
sub sp, sp, #0x10
str x30, [sp]
mov x0, x25
lsr w1, w23, #8
bl expand_common
mov x25, x0
mov w0, #0x84c0
ldr x30, [sp]
add sp, sp, #0x10
ret

// Marker -> fxRender second upload entry.
.word 0xfeed5003
fx_second:
sub sp, sp, #0x10
str x30, [sp]
str w8, [sp, #8]
lsl w23, w8, #8
mov x0, x20
mov w1, w8
bl expand_common
mov x20, x0
mov w0, #0x84c0
ldr w8, [sp, #8]
ldr x30, [sp]
add sp, sp, #0x10
ret

expand_common:
cmp w1, #3
b.lo expand_passthrough

// x6 = renderer globals; x7 = scratch at allocation + 12 MiB.
.word 0xfeed50a0
add x6, x6, #0x1f8
ldr x7, [x6]
mov x5, #0xc00000
add x7, x7, x5
ldr w3, [x6, #0x95c]
cmp w3, #0x10
b.eq pixels16

cmp w1, #3
b.eq s3_32

// 4x RGBA8888: contiguous 512x384 -> 1024x768.
mov x10, x0
mov x11, x7
mov w12, wzr
s4_32_row:
mov x13, x10
add x14, x10, #0x800
mov x15, x11
add x16, x11, #0x1, lsl #12
add x17, x11, #0x2, lsl #12
add x3, x11, #0x3, lsl #12
mov w8, wzr
s4_32_pixel:
ldr w2, [x13], #4
ldr w5, [x14], #4
str w2, [x15], #4
str w2, [x15], #4
str w2, [x16], #4
str w2, [x16], #4
str w5, [x17], #4
str w5, [x17], #4
str w5, [x3], #4
str w5, [x3], #4
add w8, w8, #1
cmp w8, #0x200
b.ne s4_32_pixel
add x10, x10, #0x1, lsl #12
add x11, x11, #0x4, lsl #12
add w12, w12, #1
cmp w12, #0xc0
b.ne s4_32_row
mov x0, x7
ret

s3_32:
mov x10, x0
mov x11, x7
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
ldp w2, w5, [x13], #8
ldp w3, w4, [x14], #8
str w2, [x15], #4
str w2, [x15], #4
str w5, [x15], #4
str w2, [x16], #4
str w2, [x16], #4
str w5, [x16], #4
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
mov x0, x7
ret

pixels16:
cmp w1, #3
b.eq s3_16

// 4x RGB565.
mov x10, x0
mov x11, x7
mov w12, wzr
s4_16_row:
mov x13, x10
add x14, x10, #0x400
mov x15, x11
add x16, x11, #0x800
add x17, x11, #0x1, lsl #12
add x3, x11, #0x1, lsl #12
add x3, x3, #0x800
mov w8, wzr
s4_16_pixel:
ldrh w2, [x13], #2
ldrh w5, [x14], #2
strh w2, [x15], #2
strh w2, [x15], #2
strh w2, [x16], #2
strh w2, [x16], #2
strh w5, [x17], #2
strh w5, [x17], #2
strh w5, [x3], #2
strh w5, [x3], #2
add w8, w8, #1
cmp w8, #0x200
b.ne s4_16_pixel
add x10, x10, #0x800
add x11, x11, #0x2, lsl #12
add w12, w12, #1
cmp w12, #0xc0
b.ne s4_16_row
mov x0, x7
ret

s3_16:
mov x10, x0
mov x11, x7
mov w12, wzr
s3_16_row:
mov x13, x10
add x14, x10, #0x400
mov x15, x11
add x16, x11, #0x600
add x17, x11, #0xc00
mov w8, wzr
s3_16_pixel:
ldrh w2, [x13], #2
ldrh w5, [x13], #2
ldrh w3, [x14], #2
ldrh w4, [x14], #2
strh w2, [x15], #2
strh w2, [x15], #2
strh w5, [x15], #2
strh w2, [x16], #2
strh w2, [x16], #2
strh w5, [x16], #2
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
mov x0, x7
ret

expand_passthrough:
ret
