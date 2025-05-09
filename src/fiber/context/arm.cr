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
    #                  r0             , r1

    # ARM assembly requires integer literals to be moved to a register before
    # being stored at an address; we use r4 as a scratch register that will be
    # overwritten by the new context.
    #
    # Eventually reset LR to zero to avoid the ARM unwinder to mistake the
    # context switch as a regular call.
    #
    # NOTE: depending on the ARM architecture (v7, v6 or older) LLVM uses
    # different strategies for atomics. By default it uses the "older"
    # architecture that relies on the libgcc __sync_* symbols; when an armv6 CPU
    # or +v6 feature is specified it uses the coprocessor instruction as used
    # below, unless the +db (data barrier) feature is set, in which case it
    # uses the `dmb ish` instruction. The +db feature is always enabled since
    # armv7 / +v7.
    #
    # TODO: we should do the same, but we don't know the list of CPU features
    # for the current target machine (and LLVM won't tell us).

    {% if compare_versions(Crystal::LLVM_VERSION, "9.0.0") >= 0 %}
      asm("
        {% if flag?(:armhf) %}
        // declare the presence of a conservative FPU to the ASM compiler
        .fpu vfp
        {% end %}

        stmdb  sp!, {r0, r4-r11, lr}  // push 1st argument + callee-saved registers
        {% if flag?(:armhf) %}
        vstmdb sp!, {d8-d15}          // push FPU registers
        {% end %}
        str    sp, [r0, #0]           // current_context.stack_top = sp
        {% if flag?(:execution_context) %}
        mov    r4, #0                 // barrier: ensure registers are stored
        mcr    p15, #0, r4, c7, c10, #5
        {% end %}
        mov    r4, #1                 // current_context.resumable = 1
        str    r4, [r0, #4]

        mov    r4, #0                 // new_context.resumable = 0
        str    r4, [r1, #4]
        ldr    sp, [r1, #0]           // sp = new_context.stack_top
        {% if flag?(:armhf) %}
        vldmia sp!, {d8-d15}          // pop FPU registers
        {% end %}
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
        {% if flag?(:armhf) %}
        // declare the presence of a conservative FPU to the ASM compiler
        .fpu vfp
        {% end %}

        stmdb  sp!, {r0, r4-r11, lr}  // push 1st argument + callee-saved registers
        {% if flag?(:armhf) %}
        vstmdb sp!, {d8-d15}          // push FPU registers
        {% end %}
        str    sp, [$0, #0]           // current_context.stack_top = sp
        {% if flag?(:execution_context) %}
        mov    r4, #0                 // barrier: ensure registers are stored
        mcr    p15, #0, r4, c7, c10, #5
        {% end %}
        mov    r4, #1                 // current_context.resumable = 1
        str    r4, [$0, #4]

        mov    r4, #0                 // new_context.resumable = 0
        str    r4, [$1, #4]
        ldr    sp, [$1, #0]           // sp = new_context.stack_top
        {% if flag?(:armhf) %}
        vldmia sp!, {d8-d15}          // pop FPU registers
        {% end %}
        ldmia  sp!, {r0, r4-r11, lr}  // pop 1st argument + callee-saved registers

        // avoid a stack corruption that will confuse the unwinder
        mov    r1, lr
        mov    lr, #0
        mov    pc, r1
        " :: "r"(current_context), "r"(new_context))
    {% end %}
  end
end
