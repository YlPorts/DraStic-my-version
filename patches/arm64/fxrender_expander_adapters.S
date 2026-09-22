.text
// fxRender adapters that reuse the common expander installed at 0xf063c.

// First screen: x25=source, w23=width, x24=renderer globals.
// Replaces "mov w0,#0x84c0" before glActiveTexture.
fx_top:
stp x27, x30, [sp, #-16]!
mov x27, x24
mov x0, x25
lsr w1, w23, #8
sub w1, w1, #1
.word 0xfeed4001
mov x25, x0
mov w0, #0x84c0
ldp x27, x30, [sp], #16
ret

.word 0xfeed4002
// Second screen: x20=source, w8=scale (1..4), x24=renderer globals.
// Replaces "lsl w23,w8,#8".
fx_bottom:
stp x27, x30, [sp, #-16]!
mov x27, x24
lsl w23, w8, #8
mov x0, x20
sub w1, w8, #1
.word 0xfeed4003
mov x20, x0
mov w0, #0x84c0
ldp x27, x30, [sp], #16
ret
