.text
// fxRender wrappers. N's common expander lives at 0xF063C.
// fxRender's renderer globals are in x24; N common expects them in x27.
// The wrappers preserve x27 and LR, expand source when scale >= 3,
// then perform the glActiveTexture(GL_TEXTURE0) call they replace.

first_fx:
stp x27, x30, [sp, #-0x10]!
mov x27, x24
mov x0, x25
.word 0xfeed4001          // load packed scale index into w1
.word 0xfeed4002          // BL N common expander
mov x25, x0
mov w0, #0x84c0
.word 0xfeed4003          // BL glActiveTexture@plt
ldp x27, x30, [sp], #0x10
ret

.word 0xfeed4004          // marker before second wrapper
second_fx:
stp x27, x30, [sp, #-0x10]!
mov x27, x24
mov x0, x20
.word 0xfeed4005          // load packed scale index into w1
.word 0xfeed4006          // BL N common expander
mov x20, x0
mov w0, #0x84c0
.word 0xfeed4007          // BL glActiveTexture@plt
ldp x27, x30, [sp], #0x10
ret
