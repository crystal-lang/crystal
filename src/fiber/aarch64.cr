{% skip_file unless flag?(:aarch64) %}

class Fiber
  # :nodoc:
  def makecontext(stack_ptr, fiber_main) : Void*
    # in ARMv8, the context switch push/pops 12 registers + 8 FPU registers.
    # add one more to store the argument of `fiber_main` (+ alignment)
    @stack_top = (stack_ptr - 22).as(Void*)

    stack_ptr[-2] = self.as(Void*)      # this will be `pop` into r0 (first argument)
    stack_ptr[-14] = fiber_main.pointer # initial `resume` will `ret` to this address
  end

  # :nodoc:
  @[NoInline]
  @[Naked]
  def self.swapcontext(current, to) : Nil
    # adapted from https://github.com/ldc-developers/druntime/blob/ldc/src/core/threadasm.S
    #
    # preserve/restore AAPCS64 registers
    # x19-x28   5.1.1 64-bit callee saved
    # x29       fp, or possibly callee saved reg - depends on platform choice 5.2.3)
    # x30       lr
    # x0        self argument (initial call)
    # d8-d15    5.1.2 says callee only must save bottom 64-bits (the "d" regs)
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
      stp     x0,  x1,  [sp, #20*8] // self, alignment

      mov     x19, sp
      str     x19, [$0]
      mov     sp, $1

      ldp     x0,  x1,  [sp, #20*8] // self, alignment
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
      "
            :: "r"(current), "r"(to))
  end
end
