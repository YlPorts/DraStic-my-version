.text
// Expand the legacy 2x framebuffer at the exact upload boundary.
// All four entry points are called in place of "str source,[sp]" immediately
// before glTexSubImage2D. GL args x0-x7 are already live, so this helper only
// uses x8-x17 and leaves x0-x7 untouched.
//
// The upload width in w4 determines the requested scale:
//  768  => 3x
// 1024  => 4x
// Anything else is passed through unchanged.
// w7 is GL type: 0x1401 (UNSIGNED_BYTE) => 4 bytes/pixel; otherwise 2 bytes.

.word 0xfeed4001
render_top:
mov x8, x9
b common

.word 0xfeed4002
render_bottom:
b common

.word 0xfeed4003
fx_top:
mov x8, x25
b common

.word 0xfeed4004
fx_bottom:
mov x8, x20
b common

common:
cmp w4, #0x300
b.eq scale3
cmp w4, #0x400
b.eq scale4

passthrough:
str x8, [sp]
ret

// Load scratch = renderer_buffer_base + 12 MiB.
// Renderer globals are fixed at 0x3f2d1f8 in this binary.
scratch:
.word 0xfeed4005
add x9, x9, #0x1f8
ldr x9, [x9]
mov x10, #0xc00000
add x10, x9, x10
ret

scale3:
sub sp, sp, #0x20
str x30, [sp, #0x18]
bl scratch
str x10, [sp, #0x10]
// x8=src, x10=dst scratch
mov w11, #0x1401
cmp w7, w11
b.eq scale3_32
b scale3_16

scale4:
sub sp, sp, #0x20
str x30, [sp, #0x18]
bl scratch
str x10, [sp, #0x10]
mov w11, #0x1401
cmp w7, w11
b.eq scale4_32
b scale4_16

// -------------------- 3x RGBA8888 --------------------
// Source is 512x384. Process 192 source row-pairs.
// Top source row -> two 768px rows, bottom -> one 768px row.
scale3_32:
mov x9, x8
mov x11, x10
mov w16, wzr
s3_32_rows:
mov x12, x9
add x13, x9, #0x800
mov x14, x11
add x15, x11, #0xc00
mov w17, wzr
s3_32_top:
ldp w8, w10, [x12], #8
str w8, [x14], #4
str w8, [x14], #4
str w10, [x14], #4
str w8, [x15], #4
str w8, [x15], #4
str w10, [x15], #4
add w17, w17, #1
cmp w17, #0x100
b.ne s3_32_top

add x14, x11, #0x1, lsl #12
add x14, x14, #0x800
mov w17, wzr
s3_32_bottom:
ldp w8, w10, [x13], #8
str w8, [x14], #4
str w8, [x14], #4
str w10, [x14], #4
add w17, w17, #1
cmp w17, #0x100
b.ne s3_32_bottom

add x9, x9, #0x1, lsl #12
add x11, x11, #0x2, lsl #12
add x11, x11, #0x400
add w16, w16, #1
cmp w16, #0xc0
b.ne s3_32_rows
b upload_scratch

// -------------------- 4x RGBA8888 --------------------
// Duplicate every 512px source row horizontally and vertically.
scale4_32:
mov x9, x8
mov x11, x10
mov w16, wzr
s4_32_rows:
mov x12, x9
mov x14, x11
add x15, x11, #0x1, lsl #12
mov w17, wzr
s4_32_top:
ldr w8, [x12], #4
str w8, [x14], #4
str w8, [x14], #4
str w8, [x15], #4
str w8, [x15], #4
add w17, w17, #1
cmp w17, #0x200
b.ne s4_32_top

add x12, x9, #0x800
add x14, x11, #0x2, lsl #12
add x15, x11, #0x3, lsl #12
mov w17, wzr
s4_32_bottom:
ldr w8, [x12], #4
str w8, [x14], #4
str w8, [x14], #4
str w8, [x15], #4
str w8, [x15], #4
add w17, w17, #1
cmp w17, #0x200
b.ne s4_32_bottom

add x9, x9, #0x1, lsl #12
add x11, x11, #0x4, lsl #12
add w16, w16, #1
cmp w16, #0xc0
b.ne s4_32_rows
b upload_scratch

// -------------------- 3x RGB565 --------------------
scale3_16:
mov x9, x8
mov x11, x10
mov w16, wzr
s3_16_rows:
mov x12, x9
add x13, x9, #0x400
mov x14, x11
add x15, x11, #0x600
mov w17, wzr
s3_16_top:
ldrh w8, [x12], #2
ldrh w10, [x12], #2
strh w8, [x14], #2
strh w8, [x14], #2
strh w10, [x14], #2
strh w8, [x15], #2
strh w8, [x15], #2
strh w10, [x15], #2
add w17, w17, #1
cmp w17, #0x100
b.ne s3_16_top

add x14, x11, #0xc00
mov w17, wzr
s3_16_bottom:
ldrh w8, [x13], #2
ldrh w10, [x13], #2
strh w8, [x14], #2
strh w8, [x14], #2
strh w10, [x14], #2
add w17, w17, #1
cmp w17, #0x100
b.ne s3_16_bottom

add x9, x9, #0x800
add x11, x11, #0x1, lsl #12
add x11, x11, #0x200
add w16, w16, #1
cmp w16, #0xc0
b.ne s3_16_rows
b upload_scratch

// -------------------- 4x RGB565 --------------------
scale4_16:
mov x9, x8
mov x11, x10
mov w16, wzr
s4_16_rows:
mov x12, x9
mov x14, x11
add x15, x11, #0x800
mov w17, wzr
s4_16_top:
ldrh w8, [x12], #2
strh w8, [x14], #2
strh w8, [x14], #2
strh w8, [x15], #2
strh w8, [x15], #2
add w17, w17, #1
cmp w17, #0x200
b.ne s4_16_top

add x12, x9, #0x400
add x14, x11, #0x1, lsl #12
add x15, x14, #0x800
mov w17, wzr
s4_16_bottom:
ldrh w8, [x12], #2
strh w8, [x14], #2
strh w8, [x14], #2
strh w8, [x15], #2
strh w8, [x15], #2
add w17, w17, #1
cmp w17, #0x200
b.ne s4_16_bottom

add x9, x9, #0x800
add x11, x11, #0x2, lsl #12
add w16, w16, #1
cmp w16, #0xc0
b.ne s4_16_rows

upload_scratch:
ldr x10, [sp, #0x10]
ldr x30, [sp, #0x18]
add sp, sp, #0x20
str x10, [sp]
ret
