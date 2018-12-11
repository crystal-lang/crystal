{% skip_file unless flag?(:i686) %}

class Fiber
  # :nodoc:
  def makecontext(stack_ptr, fiber_main)
    # in IA32, the context switch push/pops 4 registers.
    # add two more to store the argument of `fiber_main`:
    @stack_top = (stack_ptr - 6).as(Void*)

    stack_ptr[0] = self.as(Void*)      # first argument passed on the stack
    stack_ptr[-1] = Pointer(Void).null # empty space to keep the stack alignment (16 bytes)
    stack_ptr[-2] = fiber_main.pointer # initial `resume` will `ret` to this address
  end

  # :nodoc:
  @[NoInline]
  @[Naked]
  def self.swapcontext(current, to) : Nil
    asm("
      pushl %edi
      pushl %ebx
      pushl %ebp
      pushl %esi
      movl %esp, ($0)

      movl $1, %esp
      popl %esi
      popl %ebp
      popl %ebx
      popl %edi"
            :: "r"(current), "r"(to))
  end
end
