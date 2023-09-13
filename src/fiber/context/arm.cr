{% skip_file unless flag?(:arm) %}

class Fiber
  # :nodoc:
  def makecontext(stack_ptr, fiber_main) : Void*
    # in ARMv6 / ARVMv7, the context switch push/pop 8 registers, add one more
    # to store the argument of `fiber_main`, and 8 64-bit FPU registers if a FPU
    # is present, we thus reserve space for 9 or 25 pointers:
    {% if flag?(:armhf) %}
      @context.stack_top = (stack_ptr - 25).as(Void*)
    {% else %}
      @context.stack_top = (stack_ptr - 9).as(Void*)
    {% end %}
    @context.resumable = 1

    stack_ptr[0] = fiber_main.pointer # lr: initial `resume` will `ret` to this address
    stack_ptr[-9] = self.as(Void*)    # r0: puts `self` as first argument for `fiber_main`
  end

  # :nodoc:
  @[NoInline]
  @[Naked]
  def self.swapcontext(current_context, new_context) : Nil
    # ARM assembly requires integer literals to be moved to a register before
    # being stored at an address; we use r4 as a scratch register that will be
    # overwritten by the new context.
    #
    # Eventually reset LR to zero to avoid the ARM unwinder to mistake the
    # context switch as a regular call.

    {% if flag?(:armhf) %}
      #                r0             , r1
      {% if compare_versions(Crystal::LLVM_VERSION, "9.0.0") >= 0 %}
        asm("
          // declare the presence of a conservative FPU to the ASM compiler
          .fpu vfp

          stmdb  sp!, {r0, r4-r11, lr}  // push 1st argument + callee-saved registers
          vstmdb sp!, {d8-d15}          // push FPU registers
          str    sp, [r0, #0]           // current_context.stack_top = sp
          mov    r4, #1                 // current_context.resumable = 1
          str    r4, [r0, #4]

          mov    r4, #0                 // new_context.resumable = 0
          str    r4, [r1, #4]
          ldr    sp, [r1, #0]           // sp = new_context.stack_top
          vldmia sp!, {d8-d15}          // pop FPU registers
          ldmia  sp!, {r0, r4-r11, lr}  // pop 1st argument + callee-saved registers

          // avoid a stack corruption that will confuse the unwinder
          mov    r1, lr
          mov    lr, #0
          mov    pc, r1
          ")
      {% else %}
        # On LLVM < 9.0 using the previous code emits some additional
        # instructions that breaks the context switching.
        asm("
          // declare the presence of a conservative FPU to the ASM compiler
          .fpu vfp

          stmdb  sp!, {r0, r4-r11, lr}  // push 1st argument + callee-saved registers
          vstmdb sp!, {d8-d15}          // push FPU registers
          str    sp, [$0, #0]           // current_context.stack_top = sp
          mov    r4, #1                 // current_context.resumable = 1
          str    r4, [$0, #4]

          mov    r4, #0                 // new_context.resumable = 0
          str    r4, [$1, #4]
          ldr    sp, [$1, #0]           // sp = new_context.stack_top
          vldmia sp!, {d8-d15}          // pop FPU registers
          ldmia  sp!, {r0, r4-r11, lr}  // pop 1st argument + callee-saved registers

          // avoid a stack corruption that will confuse the unwinder
          mov    r1, lr
          mov    lr, #0
          mov    pc, r1
          " :: "r"(current_context), "r"(new_context))
      {% end %}
    {% elsif flag?(:arm) %}
      {% if compare_versions(Crystal::LLVM_VERSION, "9.0.0") >= 0 %}
        asm("
          stmdb  sp!, {r0, r4-r11, lr}  // push 1st argument + callee-saved registers
          str    sp, [r0, #0]           // current_context.stack_top = sp
          mov    r4, #1                 // current_context.resumable = 1
          str    r4, [r0, #4]

          mov    r4, #0                 // new_context.resumable = 0
          str    r4, [r1, #4]
          ldr    sp, [r1, #0]           // sp = new_context.stack_top
          ldmia  sp!, {r0, r4-r11, lr}  // pop 1st argument + callee-saved registers

          // avoid a stack corruption that will confuse the unwinder
          mov    r1, lr
          mov    lr, #0
          mov    pc, r1
          ")
      {% else %}
        # On LLVM < 9.0 using the previous code emits some additional
        # instructions that breaks the context switching.
        asm("
          stmdb  sp!, {r0, r4-r11, lr}  // push 1st argument + callee-saved registers
          str    sp, [$0, #0]           // current_context.stack_top = sp
          mov    r4, #1                 // current_context.resumable = 1
          str    r4, [$0, #4]

          mov    r4, #0                 // new_context.resumable = 0
          str    r4, [$1, #4]
          ldr    sp, [$1, #0]           // sp = new_context.stack_top
          ldmia  sp!, {r0, r4-r11, lr}  // pop 1st argument + callee-saved registers

          // avoid a stack corruption that will confuse the unwinder
          mov    r1, lr
          mov    lr, #0
          mov    pc, r1
          " :: "r"(current_context), "r"(new_context))
      {% end %}
    {% end %}
  end
end
