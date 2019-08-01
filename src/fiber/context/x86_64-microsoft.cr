{% skip_file unless flag?(:x86_64) && flag?(:win32) %}

class Fiber
  # :nodoc:
  def makecontext(stack_ptr, fiber_main) : Nil
    # In x86-64, the context switch push/pop 9 registers
    @context.stack_top = (stack_ptr - 9).as(Void*)
    @context.resumable = 1

    stack_ptr[0] = fiber_main.pointer # %rbx: Initial `resume` will `ret` to this address
    stack_ptr[-1] = self.as(Void*)    # %rcx: puts `self` as first argument for `fiber_main`
  end

  # :nodoc:
  @[NoInline]
  @[Naked]
  def self.swapcontext(current_context, new_context) : Nil
    asm("
          pushq %rcx
          pushq %rdi        // push 1st argument (because of initial resume)
          pushq %rbx        // push callee-saved registers on the stack
          pushq %rbp
          pushq %rsi
          pushq %r12
          pushq %r13
          pushq %r14
          pushq %r15
          movq %rsp, 0($0)  // current_context.stack_top = %rsp
          movl $$1, 8($0)   // current_context.resumable = 1

          movl $$0, 8($1)   // new_context.resumable = 0
          movq 0($1), %rsp  // %rsp = new_context.stack_top
          popq %r15         // pop callee-saved registers from the stack
          popq %r14
          popq %r13
          popq %r12
          popq %rsi
          popq %rbp
          popq %rbx
          popq %rdi         // pop 1st argument (for initial resume)
          popq %rcx
          "
            :: "r"(current_context), "r"(new_context))
  end
end
