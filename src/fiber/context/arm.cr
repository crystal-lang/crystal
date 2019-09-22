{% skip_file unless flag?(:arm) %}

class Fiber
  # :nodoc:
  def makecontext(stack_ptr, fiber_main) : Nil
    # In ARMv6 / ARMv7, we need to store the argument of `fiber_main`, `fiber_main` and
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
    # ARM assembly requires integer literals to be moved to a register before
    # being stored at an address; we use r4 as a scratch register that will be
    # overwritten by the new context.
    #
    # The stack top of new_context will always be return address, so we assign
    # pc(program counter) to that address.
    #
    # Stack Information
    #
    # |           :           |
    # +-----------------------+
    # |      link register    |
    # +-----------------------+
    # | callee-saved register |
    # +-----------------------+
    # |     resume_context    |
    # +-----------------------+

    {% if flag?(:armhf) %}
      asm("
        // declare the presence of a conservative FPU to the ASM compiler
        .fpu vfp

        stmdb  sp!, {r4-r11, lr}      // push callee-saved registers + return address
        vstmdb sp!, {d8-d15}          // push FPU registers

        // store resume_context address
        stmdb  sp!, {$2}

        str    sp, [$0, #0]           // current_context.stack_top = sp
        mov    r4, #1                 // current_context.resumable = 1
        str    r4, [$0, #4]

        mov    r4, #0                 // new_context.resumable = 0
        str    r4, [$1, #4]
        ldr    sp, [$1, #0]           // sp = new_context.stack_top

        ldmia  sp!, {pc}
        " :: "r"(current_context), "r"(new_context), "r"(resume_func))
    {% elsif flag?(:arm) %}
      asm("
        stmdb  sp!, {r4-r11, lr}      // push calleed-saved registers + return address

        // store resume_context address
        stmdb  sp!, {$2}

        str    sp, [$0, #0]           // current_context.stack_top = sp
        mov    r4, #1                 // current_context.resumable = 1
        str    r4, [$0, #4]

        mov    r4, #0                 // new_context.resumable = 0
        str    r4, [$1, #4]
        ldr    sp, [$1, #0]           // sp = new_context.stack_top

        ldmia  sp, {pc}
        " :: "r"(current_context), "r"(new_context), "r"(resume_func))
    {% end %}
  end

  @[NoInline]
  @[Naked]
  private def self.resume_context
    {% if flag?(:armhf) %}
      asm("
        // avoid a stack corruption that will confuse the unwinder
        mov    lr, #0

        vldmia sp!, {d8-d15}          // pop FPU registers
        ldmia  sp!, {r4-r11, pc}      // pop calleed-saved registers and return
        ")
    {% elsif flag?(:arm) %}
      asm("
        // avoid a stack corruption that will confuse the unwinder
        mov    lr, #0

        ldmia  sp!, {r4-r11, pc}      // pop calleed-saved registers and return
        ")
    {% end %}
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
    # |     first argument     | ---> for r0 register
    # +------------------------+

    asm("
        ldmia sp!, {r0, r4, lr}
        mov pc, r4
        ")
  end
end
