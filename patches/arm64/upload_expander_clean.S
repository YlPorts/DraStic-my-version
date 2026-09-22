.text

.macro SAVE_CALLER
sub sp, sp, #0xa0
stp x0, x1, [sp, #0x00]
stp x2, x3, [sp, #0x10]
stp x6, x7, [sp, #0x20]
stp x8, x9, [sp, #0x30]
stp x10, x11, [sp, #0x40]
stp x12, x13, [sp, #0x50]
stp x14, x15, [sp, #0x60]
stp x16, x17, [sp, #0x70]
stp x18, x30, [sp, #0x80]
.endm

.macro RESTORE_CALLER
ldp x18, x30, [sp, #0x80]
ldp x16, x17, [sp, #0x70]
ldp x14, x15, [sp, #0x60]
ldp x12, x13, [sp, #0x50]
ldp x10, x11, [sp, #0x40]
ldp x8, x9, [sp, #0x30]
ldp x6, x7, [sp, #0x20]
ldp x2, x3, [sp, #0x10]
ldp x0, x1, [sp, #0x00]
add sp, sp, #0xa0
ret
.endm

render_top:
SAVE_CALLER
mov x0, x9
bl common_expand
add x18, sp, #0xa0
str x0, [x18]
RESTORE_CALLER

.word 0xfeed4101
render_bottom:
SAVE_CALLER
mov x0, x8
bl common_expand
add x18, sp, #0xa0
str x0, [x18]
RESTORE_CALLER

.word 0xfeed4102
fx_top:
SAVE_CALLER
mov x0, x25
bl common_expand
add x18, sp, #0xa0
str x0, [x18]
RESTORE_CALLER

.word 0xfeed4103
fx_bottom:
SAVE_CALLER
mov x0, x20
bl common_expand
add x18, sp, #0xa0
str x0, [x18]
RESTORE_CALLER

common_expand:
.word 0xfeed4001
ldr x9, [x9, #0x468]
ubfx x10, x9, #51, #2
add w10, w10, #1
cmp w10, #3
b.lo finish

.word 0xfeed4002
add x11, x11, #0x1f8
ldr x12, [x11]
add x12, x12, #0x300, lsl #12
ldr w13, [x11, #0x95c]
cmp w13, #0x10
b.eq pixels16

cmp w10, #3
b.eq s3_32

mov x14, x0
mov x15, x12
mov w13, wzr
s4_32_row:
mov x1, x14
add x2, x14, #0x800
mov x3, x15
add x6, x15, #0x1, lsl #12
add x7, x15, #0x2, lsl #12
add x8, x15, #0x3, lsl #12
mov w9, wzr
s4_32_pixel:
ldr w16, [x1], #4
ldr w17, [x2], #4
str w16, [x3], #4
str w16, [x3], #4
str w16, [x6], #4
str w16, [x6], #4
str w17, [x7], #4
str w17, [x7], #4
str w17, [x8], #4
str w17, [x8], #4
add w9, w9, #1
cmp w9, #0x200
b.ne s4_32_pixel
add x14, x14, #0x1, lsl #12
add x15, x15, #0x4, lsl #12
add w13, w13, #1
cmp w13, #0xc0
b.ne s4_32_row
mov x0, x12
b finish

s3_32:
mov x14, x0
mov x15, x12
mov w13, wzr
s3_32_row:
mov x1, x14
add x2, x14, #0x800
mov x3, x15
add x6, x15, #0xc00
add x7, x15, #0x1, lsl #12
add x7, x7, #0x800
mov w9, wzr
s3_32_pixel:
ldp w16, w17, [x1], #8
ldp w8, w5, [x2], #8
str w16, [x3], #4
str w16, [x3], #4
str w17, [x3], #4
str w16, [x6], #4
str w16, [x6], #4
str w17, [x6], #4
str w8, [x7], #4
str w8, [x7], #4
str w5, [x7], #4
add w9, w9, #1
cmp w9, #0x100
b.ne s3_32_pixel
add x14, x14, #0x1, lsl #12
add x15, x15, #0x2, lsl #12
add x15, x15, #0x400
add w13, w13, #1
cmp w13, #0xc0
b.ne s3_32_row
mov x0, x12
b finish

pixels16:
cmp w10, #3
b.eq s3_16

mov x14, x0
mov x15, x12
mov w13, wzr
s4_16_row:
mov x1, x14
add x2, x14, #0x400
mov x3, x15
add x6, x15, #0x800
add x7, x15, #0x1, lsl #12
add x8, x15, #0x1, lsl #12
add x8, x8, #0x800
mov w9, wzr
s4_16_pixel:
ldrh w16, [x1], #2
ldrh w17, [x2], #2
strh w16, [x3], #2
strh w16, [x3], #2
strh w16, [x6], #2
strh w16, [x6], #2
strh w17, [x7], #2
strh w17, [x7], #2
strh w17, [x8], #2
strh w17, [x8], #2
add w9, w9, #1
cmp w9, #0x200
b.ne s4_16_pixel
add x14, x14, #0x800
add x15, x15, #0x2, lsl #12
add w13, w13, #1
cmp w13, #0xc0
b.ne s4_16_row
mov x0, x12
b finish

s3_16:
mov x14, x0
mov x15, x12
mov w13, wzr
s3_16_row:
mov x1, x14
add x2, x14, #0x400
mov x3, x15
add x6, x15, #0x600
add x7, x15, #0xc00
mov w9, wzr
s3_16_pixel:
ldrh w16, [x1], #2
ldrh w17, [x1], #2
ldrh w8, [x2], #2
ldrh w5, [x2], #2
strh w16, [x3], #2
strh w16, [x3], #2
strh w17, [x3], #2
strh w16, [x6], #2
strh w16, [x6], #2
strh w17, [x6], #2
strh w8, [x7], #2
strh w8, [x7], #2
strh w5, [x7], #2
add w9, w9, #1
cmp w9, #0x100
b.ne s3_16_pixel
add x14, x14, #0x800
add x15, x15, #0x1, lsl #12
add x15, x15, #0x200
add w13, w13, #1
cmp w13, #0xc0
b.ne s3_16_row
mov x0, x12

finish:
lsl w4, w10, #8
add w5, w10, w10, lsl #1
lsl w5, w5, #6
ret
