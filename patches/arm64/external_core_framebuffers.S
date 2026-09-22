.text
// Replace the inline 2x-only framebuffer pair created by the original
// initializer at 0x5fb28 with a separately allocated 4x-capable pair.
//
// x0 = emulator state base.
// Metadata slots remain at state+0x249498, but now point to a 6 MiB block:
//   slot A = base
//   slot B = base + 0x300000
// This avoids overwriting state fields that follow the original 1.5 MiB
// inline 2x storage.

sub sp, sp, #0x40
stp x19, x20, [sp, #0x10]
stp x21, x30, [sp, #0x20]

mov x19, x0

mov w0, #0x600000
.word 0xfeed1001          // patched to BL malloc@plt (0x15ea0)
mov x21, x0
cbz x21, alloc_failed

mov x0, x21
mov w1, wzr
mov w2, #0x600000
.word 0xfeed1002          // patched to BL memset@plt (0x16570)

mov w8, #0x9498
movk w8, #0x24, lsl #16
add x20, x19, x8

add x9, x21, #0x300, lsl #12
stp x9, x21, [x20, #8]
str x21, [x20]
b done

alloc_failed:
// Keep the app alive if allocation unexpectedly fails. Falling back to
// the original inline 2x layout is preferable to a startup crash.
mov x21, x19
mov w8, #0x9498
movk w8, #0x24, lsl #16
add x20, x19, x8
add x9, x19, #0xc0, lsl #12
stp x9, x19, [x20, #8]
str x19, [x20]

done:
ldp x21, x30, [sp, #0x20]
ldp x19, x20, [sp, #0x10]
add sp, sp, #0x40
ret
