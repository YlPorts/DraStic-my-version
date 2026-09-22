.text
// Expand the legacy 512x384 FX source just before fxRender uploads it.
// The main renderer allocation has 3 MiB of scratch after its first 12 MiB.

first_fx_entry:
sub sp, sp, #0x10
str x30, [sp]
mov x0, x25
lsr w1, w23, #8
bl fx_expand_common
mov x25, x0
mov w0, #0x84c0
ldr x30, [sp]
add sp, sp, #0x10
ret

.word 0xfeed4100
second_fx_entry:
sub sp, sp, #0x10
str x30, [sp]
lsl w23, w8, #8
mov x0, x20
mov w1, w8
bl fx_expand_common
mov x20, x0
mov w0, #0x84c0
ldr x30, [sp]
add sp, sp, #0x10
ret

fx_expand_common:
cmp w1, #3
b.lo fx_passthrough

// x6 = renderer globals at 0x3f2d000 + 0x1f8.
.word 0xfeed4101
add x6, x6, #0x1f8
ldr x4, [x6]
mov x5, #0xc00000
add x4, x4, x5
ldr w3, [x6, #0x95c]
cmp w3, #0x10
b.eq fx_pixels16

cmp w1, #3
b.eq fx_s3_32

// 4x RGBA8888: 512x384 -> 1024x768.
mov x10, x0
mov x11, x4
mov w12, wzr
fx_s4_32_row:
mov x13, x10
add x14, x10, #0x800
mov x15, x11
add x16, x11, #0x1, lsl #12
add x17, x11, #0x2, lsl #12
add x3, x11, #0x3, lsl #12
mov w8, wzr
fx_s4_32_pixel:
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
b.ne fx_s4_32_pixel
add x10, x10, #0x1, lsl #12
add x11, x11, #0x4, lsl #12
add w12, w12, #1
cmp w12, #0xc0
b.ne fx_s4_32_row
.word 0xfeed4102
add x6, x6, #0x1f8
ldr x0, [x6]
mov x1, #0xc00000
add x0, x0, x1
ret

fx_s3_32:
mov x10, x0
mov x11, x4
mov w12, wzr
fx_s3_32_row:
mov x13, x10
add x14, x10, #0x800
mov x15, x11
add x16, x11, #0xc00
add x17, x11, #0x1, lsl #12
add x17, x17, #0x800
mov w8, wzr
fx_s3_32_pixel:
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
b.ne fx_s3_32_pixel
add x10, x10, #0x1, lsl #12
add x11, x11, #0x2, lsl #12
add x11, x11, #0x400
add w12, w12, #1
cmp w12, #0xc0
b.ne fx_s3_32_row
.word 0xfeed4103
add x6, x6, #0x1f8
ldr x0, [x6]
mov x1, #0xc00000
add x0, x0, x1
ret

fx_pixels16:
cmp w1, #3
b.eq fx_s3_16

// 4x RGB565: 512x384 -> 1024x768.
mov x10, x0
mov x11, x4
mov w12, wzr
fx_s4_16_row:
mov x13, x10
add x14, x10, #0x400
mov x15, x11
add x16, x11, #0x800
add x17, x11, #0x1, lsl #12
add x3, x11, #0x1, lsl #12
add x3, x3, #0x800
mov w8, wzr
fx_s4_16_pixel:
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
b.ne fx_s4_16_pixel
add x10, x10, #0x800
add x11, x11, #0x2, lsl #12
add w12, w12, #1
cmp w12, #0xc0
b.ne fx_s4_16_row
.word 0xfeed4104
add x6, x6, #0x1f8
ldr x0, [x6]
mov x1, #0xc00000
add x0, x0, x1
ret

fx_s3_16:
mov x10, x0
mov x11, x4
mov w12, wzr
fx_s3_16_row:
mov x13, x10
add x14, x10, #0x400
mov x15, x11
add x16, x11, #0x600
add x17, x11, #0xc00
mov w8, wzr
fx_s3_16_pixel:
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
b.ne fx_s3_16_pixel
add x10, x10, #0x800
add x11, x11, #0x1, lsl #12
add x11, x11, #0x200
add w12, w12, #1
cmp w12, #0xc0
b.ne fx_s3_16_row
.word 0xfeed4105
add x6, x6, #0x1f8
ldr x0, [x6]
mov x1, #0xc00000
add x0, x0, x1
ret

fx_passthrough:
ret
