{% skip_file unless flag?(:x86_64) && flag?(:unix) %}

class Fiber
  # :nodoc:
  def makecontext(stack_ptr, fiber_main) : Nil
    # in x86-64, the context switch push/pop 6 registers + the return address
    # that is left on the stack, we thus reserve space for 7 pointers:
    @context.stack_top = (stack_ptr - 7).as(Void*)
    @context.resumable = 1

    stack_ptr[0] = fiber_main.pointer # %rbx: initial `resume` will `ret` to this address
    stack_ptr[-1] = self.as(Void*)    # %rdi: puts `self` as first argument for `fiber_main`
  end

  # :nodoc:
  @[NoInline]
  @[Naked]
  def self.swapcontext(current_context, new_context) : Nil
    {% if compare_versions(Crystal::LLVM_VERSION, "9.0.0") >= 0 %}
      #                %rdi           , %rsi
      asm("
      pushq %rdi        // push 1st argument (because of initial resume)
      pushq %rbx        // push callee-saved registers on the stack
      pushq %rbp
      pushq %r12
      pushq %r13
      pushq %r14
      pushq %r15
      movq %rsp, 0(%rdi)  // current_context.stack_top = %rsp
      movl $$1, 8(%rdi)   // current_context.resumable = 1

      movl $$0, 8(%rsi)   // new_context.resumable = 0
      movq 0(%rsi), %rsp  // %rsp = new_context.stack_top
      popq %r15         // pop callee-saved registers from the stack
      popq %r14
      popq %r13
      popq %r12
      popq %rbp
      popq %rbx
      popq %rdi         // pop 1st argument (for initial resume)
      ")
    {% else %}
      # On LLVM < 9.0 using the previous code emits some additional
      # instructions that breaks the context switching.
      asm("
      pushq %rdi        // push 1st argument (because of initial resume)
      pushq %rbx        // push callee-saved registers on the stack
      pushq %rbp
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
      popq %rbp
      popq %rbx
      popq %rdi         // pop 1st argument (for initial resume)
      " :: "r"(current_context), "r"(new_context))
    {% end %}
  end
end
