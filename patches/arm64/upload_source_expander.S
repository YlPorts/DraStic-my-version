.text
// Clean upload-source expander for DraStic.
// Intercepts the pixel pointer immediately before glTexSubImage2D.
// Common input:
//   x0 = legacy framebuffer source (2x = 512x384)
//   x4 = scratch destination
//   w1 = requested factor (1..4)
//   w2 = GL pixel type (0x8363 => 16-bit RGB565, otherwise 32-bit)
// Returns:
//   x0 = upload source
//   w4 = upload width
//   w5 = upload height
//
// The four wrappers preserve GL format/type (w6/w7), restore target/x/y args,
// and write the resulting pixel pointer to the caller's [sp].

.word 0xfeed4001
render_top:
stp x6, x7, [sp, #-32]!
str x30, [sp, #16]
lsr w1, w4, #8
mov w2, w7
ldr x4, [x27]
mov x0, x9
bl expand_common
mov x9, x0
ldr x30, [sp, #16]
ldp x6, x7, [sp], #32
mov w0, #0xde1
mov w1, wzr
mov w2, wzr
mov w3, wzr
str x9, [sp]
ret

.word 0xfeed4002
render_bottom:
stp x6, x7, [sp, #-32]!
str x30, [sp, #16]
lsr w1, w4, #8
mov w2, w7
ldr x4, [x27]
mov x0, x8
bl expand_common
mov x9, x0
ldr x30, [sp, #16]
ldp x6, x7, [sp], #32
mov w0, #0xde1
mov w1, wzr
mov w2, wzr
mov w3, wzr
str x9, [sp]
ret

.word 0xfeed4003
fx_top:
stp x6, x7, [sp, #-32]!
str x30, [sp, #16]
lsr w1, w4, #8
mov w2, w7
ldr x4, [x24]
mov x0, x25
bl expand_common
mov x9, x0
ldr x30, [sp, #16]
ldp x6, x7, [sp], #32
mov w0, #0xde1
mov w1, wzr
mov w2, wzr
mov w3, wzr
str x9, [sp]
ret

.word 0xfeed4004
fx_bottom:
stp x6, x7, [sp, #-32]!
str x30, [sp, #16]
lsr w1, w4, #8
mov w2, w7
ldur x4, [x24, #-16]
mov x0, x20
bl expand_common
mov x9, x0
ldr x30, [sp, #16]
ldp x6, x7, [sp], #32
mov w0, #0xde1
mov w1, wzr
mov w2, wzr
mov w3, wzr
str x9, [sp]
ret

expand_common:
mov w9, w1
lsl w4, w9, #8
add w5, w9, w9, lsl #1
lsl w5, w5, #6
cmp w9, #3
b.lo expand_passthrough

// scratch = renderer allocation + 12 MiB
mov x18, x4
mov x8, #0xc00000
add x18, x18, x8

// Select source pixel size by GL type.
mov w8, #0x8363
cmp w2, w8
b.eq expand16

// ---------------- 32-bit RGBA path ----------------
cmp w9, #3
b.eq expand3_32

// 4x: 512x384 -> 1024x768
mov x10, x0
mov x11, x18
mov w12, wzr
e4_32_row:
mov x13, x10
add x14, x10, #0x800
mov x15, x11
add x16, x11, #0x1, lsl #12
add x17, x11, #0x2, lsl #12
add x5,  x11, #0x3, lsl #12
mov w8, wzr
e4_32_pixel:
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
b.ne e4_32_pixel
add x10, x10, #0x1, lsl #12
add x11, x11, #0x4, lsl #12
add w12, w12, #1
cmp w12, #0xc0
b.ne e4_32_row
b expanded

expand3_32:
mov x10, x0
mov x11, x18
mov w12, wzr
e3_32_row:
mov x13, x10
add x14, x10, #0x800
mov x15, x11
add x16, x11, #0xc00
add x17, x11, #0x1, lsl #12
add x17, x17, #0x800
mov w8, wzr
e3_32_pixel:
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
b.ne e3_32_pixel
add x10, x10, #0x1, lsl #12
add x11, x11, #0x2, lsl #12
add x11, x11, #0x400
add w12, w12, #1
cmp w12, #0xc0
b.ne e3_32_row
b expanded

// ---------------- 16-bit RGB565 path ----------------
expand16:
cmp w9, #3
b.eq expand3_16

// 4x: 512x384 -> 1024x768
mov x10, x0
mov x11, x18
mov w12, wzr
e4_16_row:
mov x13, x10
add x14, x10, #0x400
mov x15, x11
add x16, x11, #0x800
add x17, x11, #0x1, lsl #12
add x5,  x11, #0x1, lsl #12
add x5,  x5, #0x800
mov w8, wzr
e4_16_pixel:
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
b.ne e4_16_pixel
add x10, x10, #0x800
add x11, x11, #0x2, lsl #12
add w12, w12, #1
cmp w12, #0xc0
b.ne e4_16_row
b expanded

expand3_16:
mov x10, x0
mov x11, x18
mov w12, wzr
e3_16_row:
mov x13, x10
add x14, x10, #0x400
mov x15, x11
add x16, x11, #0x600
add x17, x11, #0xc00
mov w8, wzr
e3_16_pixel:
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
b.ne e3_16_pixel
add x10, x10, #0x800
add x11, x11, #0x1, lsl #12
add x11, x11, #0x200
add w12, w12, #1
cmp w12, #0xc0
b.ne e3_16_row

expanded:
mov x0, x18
lsl w4, w9, #8
add w5, w9, w9, lsl #1
lsl w5, w5, #6
ret

expand_passthrough:
ret
