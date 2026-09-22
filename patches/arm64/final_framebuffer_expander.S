.text
// Final framebuffer expander for the legacy 2x DraStic core output.
//
// Entry:
//   x0 = destination display framebuffer slot (4x-capable)
//   x1 = legacy core framebuffer, physically 512x384 RGBA8888
// The original function tail-called memcpy(0xC0000).
//
// scale=1/2: preserve the original 0xC0000 copy.
// scale=3: 512x384 -> 768x576, mapping each 2x2 source block to 3x3.
// scale=4: 512x384 -> 1024x768, mapping each source pixel 2x in both axes.

.word 0xfeed2001          // patched: adrp x9, packed config page
ldr x9, [x9, #0x468]
ubfx x9, x9, #51, #2
add w9, w9, #1

cmp w9, #3
b.eq scale3
cmp w9, #4
b.eq scale4

mov w2, #0xc0000
.word 0xfeed2002          // patched: B memcpy@plt

scale3:
mov x10, x1              // source group: two 512px rows
mov x11, x0              // destination group: three 768px rows
mov w12, #0              // native row group 0..191

s3_row:
mov x13, x10             // src row A
add x14, x10, #0x800     // src row B
mov x15, x11             // dst row A0
add x16, x11, #0xc00     // dst row A1
add x17, x11, #0x1, lsl #12
add x17, x17, #0x800     // dst row B
mov w8, #0               // 256 source pixel pairs

s3_pixel:
ldp w2, w3, [x13], #8
ldr w4, [x14], #4
ldr w5, [x14], #4

// Top source pair -> [A,A,B] on two output rows.
str w2, [x15], #4
str w2, [x15], #4
str w3, [x15], #4
str w2, [x16], #4
str w2, [x16], #4
str w3, [x16], #4

// Bottom source pair -> [A,A,B] on third output row.
str w4, [x17], #4
str w4, [x17], #4
str w5, [x17], #4

add w8, w8, #1
cmp w8, #0x100
b.ne s3_pixel

add x10, x10, #0x1, lsl #12    // two source rows
add x11, x11, #0x2, lsl #12
add x11, x11, #0x400             // three 768px RGBA rows
add w12, w12, #1
cmp w12, #0xc0
b.ne s3_row
ret

scale4:
mov x10, x1
mov x11, x0
mov w12, #0

s4_row:
mov x13, x10
add x14, x10, #0x800
mov x15, x11
add x16, x11, #0x1, lsl #12
add x17, x11, #0x2, lsl #12
add x6,  x11, #0x3, lsl #12
mov w8, #0

s4_pixel:
ldr w2, [x13], #4
ldr w3, [x14], #4

// Each source pixel becomes two horizontal pixels and two vertical rows.
str w2, [x15], #4
str w2, [x15], #4
str w2, [x16], #4
str w2, [x16], #4

str w3, [x17], #4
str w3, [x17], #4
str w3, [x6], #4
str w3, [x6], #4

add w8, w8, #1
cmp w8, #0x200
b.ne s4_pixel

add x10, x10, #0x1, lsl #12
add x11, x11, #0x4, lsl #12
add w12, w12, #1
cmp w12, #0xc0
b.ne s4_row
ret
