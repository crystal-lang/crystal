{% skip_file unless flag?(:x86_64) %}

class Fiber
  # :nodoc:
  def makecontext(stack_ptr, fiber_main)
    # in x86-64, the context switch push/pop 7 registers
    @stack_top = (stack_ptr - 7).as(Void*)

    stack_ptr[0] = fiber_main.pointer # initial `resume` will `ret` to this address
    stack_ptr[-1] = self.as(Void*)    # this will be `pop` into %rdi (first argument)
  end

  # :nodoc:
  @[NoInline]
  @[Naked]
  def self.swapcontext(current, to) : Nil
    asm("
      pushq %rdi
      pushq %rbx
      pushq %rbp
      pushq %r12
      pushq %r13
      pushq %r14
      pushq %r15
      movq %rsp, ($0)

      movq $1, %rsp
      popq %r15
      popq %r14
      popq %r13
      popq %r12
      popq %rbp
      popq %rbx
      popq %rdi"
            :: "r"(current), "r"(to))
  end
end
