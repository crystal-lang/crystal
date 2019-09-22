{% skip_file unless flag?(:x86_64) && flag?(:unix) %}

class Fiber
  # :nodoc:
  def makecontext(stack_ptr, fiber_main) : Nil
    # In x86-64(sysv), the stack is required 16-byte alignment before `call`
    # instruction. Because `stack_ptr` has been aligned, we don't need to
    # reserve space on alignment.  When returning to `entry function`, the
    # `RSP + 8` is 16-byte alignment.
    #
    # Initial Stack
    #
    # +-----------------------+
    # |     entry function    |
    # +-----------------------+
    # |     fiber address     |
    # +-----------------------+
    # |    helper function    | ---> load first argument and jump to entry function
    # +-----------------------+

    @context.stack_top = (stack_ptr - 2).as(Void*)
    @context.resumable = 1
    stack_ptr[0] = fiber_main.pointer
    stack_ptr[-1] = self.as(Void*)
    stack_ptr[-2] = (->Fiber.load_first_argument).pointer
  end

  @[NoInline]
  @[Naked]
  private def self.suspend_context(current_context, new_context, resume_func)
    asm("
      pushq %rbx        // push callee-saved registers on the stack
      pushq %rbp
      pushq %r12
      pushq %r13
      pushq %r14
      pushq %r15
      pushq $2          // push resume_context function_pointer
      movq %rsp, 0($0)  // current_context.stack_top = %rsp
      movl $$1, 8($0)   // current_context.resumable = 1

      movl $$0, 8($1)   // new_context.resumable = 0
      movq 0($1), %rsp  // %rsp = new_context.stack_top
      " :: "r"(current_context), "r"(new_context), "r"(resume_func))
  end

  @[NoInline]
  @[Naked]
  private def self.resume_context
    asm("
        popq %r15
        popq %r14
        popq %r13
        popq %r12
        popq %rbp
        popq %rbx
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
    # |  target function addr  | ---> for pc register
    # +------------------------+
    # |     first argument     | ---> for rdi register
    # +------------------------+

    asm("popq %rdi")
  end
end
