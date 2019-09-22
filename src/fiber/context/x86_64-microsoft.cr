{% skip_file unless flag?(:x86_64) && flag?(:win32) %}

class Fiber
  # :nodoc:
  def makecontext(stack_ptr, fiber_main) : Nil
    # A great explanation on stack contexts for win32:
    # https://cfsamson.gitbook.io/green-threads-explained-in-200-lines-of-rust/supporting-windows
    #
    # In x86-64(microsoft), the stack is required to 16-byte alignment before `call`
    # instruction. Because `stack_ptr` has been aligned, we don't need to reserve
    # space on alignment. When returning to `entry function`, `RSP + 8` is 16-byte
    # alignment.
    #
    # Initial Stack
    #
    # +-----------------------+
    # |      fiber address    |
    # +-----------------------+
    # |      clean helper     | ---> clean first argument and return
    # +-----------------------+
    # |     entry function    |
    # +-----------------------+
    # |       load helper     | ---> load first argument to %rcx and return to entry function
    # +-----------------------+
    # |       stack limit     | ---> %gs:0x10
    # +-----------------------+
    # |       stack base      | ---> %gs:0x08
    # +-----------------------+

    @context.stack_top = (stack_ptr - 5).as(Void*)
    @context.resumable = 1

    stack_ptr[0] = self.as(Void*) # %rcx: puts `self` as first argument for `fiber_main`
    stack_ptr[-1] = (->Fiber.clean_first_argument).pointer
    stack_ptr[-2] = fiber_main.pointer
    stack_ptr[-3] = (->Fiber.load_first_argument).pointer

    # The following two values are stored in the Thread Information Block (NT_TIB)
    # and are used by Windows to track the current stack limits. Hence, these two value
    # will be updated immediately after switching the stack register.
    stack_ptr[-4] = @stack        # %gs:0x10: Stack Limit
    stack_ptr[-5] = @stack_bottom # %gs:0x08: Stack Base
  end

  @[NoInline]
  @[Naked]
  private def self.suspend_context(current_context, new_context, resume_func)
    asm("
          pushq %rcx        // for stack alignment
          pushq %rdi        // push callee-saved registers on the stack
          pushq %rbx
          pushq %rbp
          pushq %rsi
          pushq %r12
          pushq %r13
          pushq %r14
          pushq %r15
          subq $$160, %rsp  // push XMM registers
          movups %xmm6, 0x00(%rsp)
          movups %xmm7, 0x10(%rsp)
          movups %xmm8, 0x20(%rsp)
          movups %xmm9, 0x30(%rsp)
          movups %xmm10, 0x40(%rsp)
          movups %xmm11, 0x50(%rsp)
          movups %xmm12, 0x60(%rsp)
          movups %xmm13, 0x70(%rsp)
          movups %xmm14, 0x80(%rsp)
          movups %xmm15, 0x90(%rsp)
          pushq $2          // push resume_context function_pointer
          pushq %gs:0x10    // Thread Information Block: Stack Limit
          pushq %gs:0x08    // Thread Information Block: Stack Base
          movq %rsp, 0($0)  // current_context.stack_top = %rsp
          movl $$1, 8($0)   // current_context.resumable = 1

          movl $$0, 8($1)   // new_context.resumable = 0
          movq 0($1), %rsp  // %rsp = new_context.stack_top
          popq %gs:0x08
          popq %gs:0x10
          "
            :: "r"(current_context), "r"(new_context), "r"(resume_func))
  end

  @[NoInline]
  @[Naked]
  private def self.resume_context
    asm("
          movups 0x00(%rsp), %xmm6 // pop XMM registers
          movups 0x10(%rsp), %xmm7
          movups 0x20(%rsp), %xmm8
          movups 0x30(%rsp), %xmm9
          movups 0x40(%rsp), %xmm10
          movups 0x50(%rsp), %xmm11
          movups 0x60(%rsp), %xmm12
          movups 0x70(%rsp), %xmm13
          movups 0x80(%rsp), %xmm14
          movups 0x90(%rsp), %xmm15
          addq $$160, %rsp
          popq %r15         // pop callee-saved registers from the stack
          popq %r14
          popq %r13
          popq %r12
          popq %rsi
          popq %rbp
          popq %rbx
          popq %rdi
          popq %rcx
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
    # |     first argument     | ---> for rcx register
    # +------------------------+
    # |  clean first argument  | ---> clean_first_argument
    # +------------------------+
    # |  target function addr  | ---> for pc register
    # +------------------------+

    asm("movq 0x10(%rsp), %rcx")
  end

  @[NoInline]
  @[Naked]
  protected def self.clean_first_argument
    asm("popq %rcx")
  end
end
