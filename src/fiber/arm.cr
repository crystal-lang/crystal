{% skip_file unless flag?(:arm) %}

class Fiber
  # :nodoc:
  def makecontext(stack_ptr, fiber_main) : Void*
    # in ARMv6 / ARVMv7, the context switch push/pops 8 registers.
    # add one more to store the argument of `fiber_main`:
    {% if flag?(:armhf) %}
      # add 8 FPU registers (64-bit).
      @stack_top = (stack_ptr - (9 + 16)).as(Void*)
    {% else %}
      @stack_top = (stack_ptr - 9).as(Void*)
    {% end %}

    stack_ptr[0] = fiber_main.pointer # initial `resume` will `ret` to this address
    stack_ptr[-9] = self.as(Void*)    # this will be `pop` into r0 (first argument)
  end

  # :nodoc:
  @[NoInline]
  @[Naked]
  def self.swapcontext(current, to) : Nil
    # eventually reset LR to zero to avoid the ARM unwinder to mistake the
    # context switch as a regular call.

    {% if flag?(:armhf) %}
      asm("
        .fpu vfp

        stmdb  sp!, {r0, r4-r11, lr}
        vstmdb sp!, {d8-d15}
        str    sp, [$0]

        mov    sp, $1
        vldmia sp!, {d8-d15}
        ldmia  sp!, {r0, r4-r11, lr}

        mov    r1, lr
        mov    lr, #0
        mov    pc, r1
        "
              :: "r"(current), "r"(to))
    {% elsif flag?(:arm) %}
      asm("
        stmdb  sp!, {r0, r4-r11, lr}
        str    sp, [$0]

        mov    sp, $1
        ldmia  sp!, {r0, r4-r11, lr}

        mov    r1, lr
        mov    lr, #0
        mov    pc, r1
        "
              :: "r"(current), "r"(to))
    {% end %}
  end
end
