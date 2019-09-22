{% skip_file unless flag?(:aarch64) %}

class Fiber
  # :nodoc:
  def makecontext(stack_ptr, fiber_main) : Nil
    # In ARMv8, we need to store the argument of `fiber_main`, `fiber_main` and
    # a helper function. The helper will assign registers in order to jump to
    # entry function.
    #
    # Initial Stack
    #
    # +-------------------------+
    # |   dummy return address  |
    # +-------------------------+
    # |      entry function     |
    # +-------------------------+
    # |      fiber address      |
    # +-------------------------+
    # |     helper function     | ---> load first argument and jump to entry function
    # +-------------------------+

    @context.stack_top = (stack_ptr - 3).as(Void*)
    @context.resumable = 1
    stack_ptr[0] = Pointer(Void).null
    stack_ptr[-1] = fiber_main.pointer
    stack_ptr[-2] = self.as(Void*)
    stack_ptr[-3] = (->Fiber.load_first_argument).pointer
  end

  @[NoInline]
  @[Naked]
  private def self.suspend_context(current_context, new_context, resume_func)
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
    # The stack top of new_context will always be return address, so we assign
    # x30(link register) to that address.
    #
    # Stack information:
    #
    # |           :          |
    # +----------------------+
    # |        x19-x30       |
    # +----------------------+
    # |         d8-d15       |
    # +----------------------+
    # |    resume_context    | <--- stack top
    # +----------------------+

    asm("
      stp     d15, d14, [sp, #-20*8]!
      stp     d13, d12, [sp, #2*8]
      stp     d11, d10, [sp, #4*8]
      stp     d9,  d8,  [sp, #6*8]
      stp     x30, x29, [sp, #8*8]  // lr, fp
      stp     x28, x27, [sp, #10*8]
      stp     x26, x25, [sp, #12*8]
      stp     x24, x23, [sp, #14*8]
      stp     x22, x21, [sp, #16*8]
      stp     x20, x19, [sp, #18*8]

      // push resume_context address
      str     $2, [sp, #-8]!

      mov     x19, sp               // current_context.stack_top = sp
      str     x19, [$0, #0]
      mov     x19, #1               // current_context.resumable = 1
      str     x19, [$0, #8]

      mov     x19, #0               // new_context.resumable = 0
      str     x19, [$1, #8]
      ldr     x19, [$1, #0]         // sp = new_context.stack_top (x19)
      mov     sp, x19

      ldr     x30, [sp], #8
      " :: "r"(current_context), "r"(new_context), "r"(resume_func))
  end

  @[NoInline]
  @[Naked]
  private def self.resume_context
    asm("
      ldp     x20, x19, [sp, #18*8]
      ldp     x22, x21, [sp, #16*8]
      ldp     x24, x23, [sp, #14*8]
      ldp     x26, x25, [sp, #12*8]
      ldp     x28, x27, [sp, #10*8]
      ldp     x30, x29, [sp, #8*8]  // lr, fp
      ldp     d9,  d8,  [sp, #6*8]
      ldp     d11, d10, [sp, #4*8]
      ldp     d13, d12, [sp, #2*8]
      ldp     d15, d14, [sp], #20*8

      // avoid a stack corruption that will confuse the unwinder
      mov     x16, x30 // save lr
      mov     x30, #0  // reset lr
      br      x16      // jump to new pc value
      ")
  end

  # :nodoc:
  def self.swapcontext(current_context, new_context) : Nil
    suspend_context current_context, new_context, (->resume_context).pointer
  end

  @[NoInline]
  @[Naked]
  protected def self.load_first_argument
    # Stack requirement
    #
    # |            :           |
    # |            :           |
    # +------------------------+
    # |  next return address   | ---> for lr register
    # +------------------------+
    # |  target function addr  | ---> for pc register
    # +------------------------+
    # |     first argument     | ---> for x0 register
    # +------------------------+

    asm("
      ldp     x16, x30, [sp, #8]
      ldr     x0, [sp], #24
      br      x16
      ")
  end
end
