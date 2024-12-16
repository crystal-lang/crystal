{% skip_file unless flag?(:aarch64) && !flag?(:win32) %}

class Fiber
  # :nodoc:
  def makecontext(stack_ptr, fiber_main) : Nil
    # in ARMv8, the context switch push/pop 12 registers and 8 FPU registers,
    # and one more to store the argument of `fiber_main` (+ alignment), we thus
    # reserve space for 22 pointers:
    @context.stack_top = (stack_ptr - 22).as(Void*)
    @context.resumable = 1

    stack_ptr[-2] = self.as(Void*)      # x0 (r0): puts `self` as first argument for `fiber_main`
    stack_ptr[-14] = fiber_main.pointer # x30 (lr): initial `resume` will `ret` to this address
  end

  # :nodoc:
  @[NoInline]
  @[Naked]
  def self.swapcontext(current_context, new_context) : Nil
    #                  x0             , x1

    # adapted from https://github.com/ldc-developers/druntime/blob/ldc/src/core/threadasm.S
    #
    # preserve/restore AAPCS64 registers:
    # x19-x28   5.1.1 64-bit callee saved
    # x29       fp, or possibly callee saved reg - depends on platform choice 5.2.3)
    # x30       lr
    # x0        self argument (initial call)
    # d8-d15    5.1.2 says callee only must save bottom 64-bits (the "d" regs)
    #
    # ARM assembly requires integer literals to be moved to a register before
    # being stored at an address; we use x19 as a scratch register that will be
    # overwritten by the new context.
    #
    # AArch64 assembly also requires a register to load/store the stack top
    # pointer. We use x19 as a scratch register again.
    #
    # Eventually reset LR to zero to avoid the ARM unwinder to mistake the
    # context switch as a regular call.

    {% if compare_versions(Crystal::LLVM_VERSION, "9.0.0") >= 0 %}
      asm("
      stp     d15, d14, [sp, #-22*8]!
      stp     d13, d12, [sp, #2*8]
      stp     d11, d10, [sp, #4*8]
      stp     d9,  d8,  [sp, #6*8]
      stp     x30, x29, [sp, #8*8]  // lr, fp
      stp     x28, x27, [sp, #10*8]
      stp     x26, x25, [sp, #12*8]
      stp     x24, x23, [sp, #14*8]
      stp     x22, x21, [sp, #16*8]
      stp     x20, x19, [sp, #18*8]
      stp     x0,  x1,  [sp, #20*8] // push 1st argument (+ alignment)

      mov     x19, sp               // current_context.stack_top = sp
      str     x19, [x0, #0]
      mov     x19, #1               // current_context.resumable = 1
      str     x19, [x0, #8]

      mov     x19, #0               // new_context.resumable = 0
      str     x19, [x1, #8]
      ldr     x19, [x1, #0]         // sp = new_context.stack_top (x19)
      mov     sp, x19

      ldp     x0,  x1,  [sp, #20*8] // pop 1st argument (+ alignment)
      ldp     x20, x19, [sp, #18*8]
      ldp     x22, x21, [sp, #16*8]
      ldp     x24, x23, [sp, #14*8]
      ldp     x26, x25, [sp, #12*8]
      ldp     x28, x27, [sp, #10*8]
      ldp     x30, x29, [sp, #8*8]  // lr, fp
      ldp     d9,  d8,  [sp, #6*8]
      ldp     d11, d10, [sp, #4*8]
      ldp     d13, d12, [sp, #2*8]
      ldp     d15, d14, [sp], #22*8

      // avoid a stack corruption that will confuse the unwinder
      mov     x16, x30 // save lr
      mov     x30, #0  // reset lr
      br      x16      // jump to new pc value
      ")
    {% else %}
      # On LLVM < 9.0 using the previous code emits some additional
      # instructions that breaks the context switching.
      asm("
      stp     d15, d14, [sp, #-22*8]!
      stp     d13, d12, [sp, #2*8]
      stp     d11, d10, [sp, #4*8]
      stp     d9,  d8,  [sp, #6*8]
      stp     x30, x29, [sp, #8*8]  // lr, fp
      stp     x28, x27, [sp, #10*8]
      stp     x26, x25, [sp, #12*8]
      stp     x24, x23, [sp, #14*8]
      stp     x22, x21, [sp, #16*8]
      stp     x20, x19, [sp, #18*8]
      stp     x0,  x1,  [sp, #20*8] // push 1st argument (+ alignment)

      mov     x19, sp               // current_context.stack_top = sp
      str     x19, [$0, #0]
      mov     x19, #1               // current_context.resumable = 1
      str     x19, [$0, #8]

      mov     x19, #0               // new_context.resumable = 0
      str     x19, [$1, #8]
      ldr     x19, [$1, #0]         // sp = new_context.stack_top (x19)
      mov     sp, x19

      ldp     x0,  x1,  [sp, #20*8] // pop 1st argument (+ alignment)
      ldp     x20, x19, [sp, #18*8]
      ldp     x22, x21, [sp, #16*8]
      ldp     x24, x23, [sp, #14*8]
      ldp     x26, x25, [sp, #12*8]
      ldp     x28, x27, [sp, #10*8]
      ldp     x30, x29, [sp, #8*8]  // lr, fp
      ldp     d9,  d8,  [sp, #6*8]
      ldp     d11, d10, [sp, #4*8]
      ldp     d13, d12, [sp, #2*8]
      ldp     d15, d14, [sp], #22*8

      // avoid a stack corruption that will confuse the unwinder
      mov     x16, x30 // save lr
      mov     x30, #0  // reset lr
      br      x16      // jump to new pc value
      " :: "r"(current_context), "r"(new_context))
    {% end %}
  end
end
