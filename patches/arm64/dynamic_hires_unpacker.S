.text
// Dynamic unpacker for DraStic's original 2x2 planar HiRes scanline.
//
// Entry from 0x4cb84:
//   x0  = source planar scanline (4 planes, 0x400 bytes each)
//   x19 = destination scanline group
//
// For 2x, jump back to the original optimized converter.
// For 3x/4x, expand the 2x2 source samples with nearest sampling into
// exactly scale rows of 256*scale RGBA pixels. This fixes layout/stride
// while the deeper rasterizer is still being generalized beyond 2x.

mov x14, x0
mov w0, wzr
.word 0xfeed0001          // patched to BL 0x1cdac (get scale index)
add w15, w0, #1
cmp w15, #2
b.ne upscale_dynamic

mov x0, x14
add x8, x14, #0x800
.word 0xfeed0002          // patched to B 0x4cb88

upscale_dynamic:
mov x10, x19
mov w8, wzr               // output sub-row y = 0

row_loop:
lsl w9, w8, #1
udiv w9, w9, w15          // source y in {0,1}
mov w11, wzr              // native x = 0

pixel_loop:
add x12, x14, w11, uxtw #2
mov w13, wzr              // output sub-x = 0

subpixel_loop:
lsl w16, w13, #1
udiv w16, w16, w15        // source x in {0,1}
add w16, w16, w9, lsl #1  // plane = sy*2 + sx
lsl x16, x16, #10         // each source plane is 0x400 bytes
add x1, x12, x16
ldr w17, [x1]

// Same RGB conversion used by the original 0x4cb84 path.
lsr w2, w17, #14
and w2, w2, #0xfc
lsr w3, w17, #8
bfi w2, w3, #10, #6
bfi w2, w17, #18, #6
str w2, [x10], #4

add w13, w13, #1
cmp w13, w15
b.ne subpixel_loop

add w11, w11, #1
cmp w11, #0x100
b.ne pixel_loop

add w8, w8, #1
cmp w8, w15
b.ne row_loop

.word 0xfeed0003          // patched to B 0x4d284
