{% skip_file unless flag?(:x86_64) && flag?(:win32) %}

class Fiber
  # :nodoc:
  def makecontext(stack_ptr, fiber_main) : Nil
    # A great explanation on stack contexts for win32:
    # https://cfsamson.gitbook.io/green-threads-explained-in-200-lines-of-rust/supporting-windows

    # 8 registers + 2 qwords for NT_TIB + 1 parameter + 10 128bit XMM registers
    @context.stack_top = (stack_ptr - (11 + 10*2)).as(Void*)
    @context.resumable = 1

    stack_ptr[0] = fiber_main.pointer # %rbx: Initial `resume` will `ret` to this address
    stack_ptr[-1] = self.as(Void*)    # %rcx: puts `self` as first argument for `fiber_main`

    # The following two values are stored in the Thread Information Block (NT_TIB)
    # and are used by Windows to track the current stack limits
    stack_ptr[-2] = @stack        # %gs:0x10: Stack Limit
    stack_ptr[-3] = @stack_bottom # %gs:0x08: Stack Base
  end

  # :nodoc:
  @[NoInline]
  @[Naked]
  def self.swapcontext(current_context, new_context) : Nil
    {% if compare_versions(Crystal::LLVM_VERSION, "9.0.0") >= 0 %}
      #                %rcx           , %rdx
      asm("
          pushq %rcx
          pushq %gs:0x10    // Thread Information Block: Stack Limit
          pushq %gs:0x08    // Thread Information Block: Stack Base
          pushq %rdi        // push 1st argument (because of initial resume)
          pushq %rbx        // push callee-saved registers on the stack
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
          movq %rsp, 0(%rcx)  // current_context.stack_top = %rsp
          movl $$1, 8(%rcx)   // current_context.resumable = 1
          movl $$0, 8(%rdx)   // new_context.resumable = 0
          movq 0(%rdx), %rsp  // %rsp = new_context.stack_top
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
          popq %rdi         // pop 1st argument (for initial resume)
          popq %gs:0x08
          popq %gs:0x10
          popq %rcx
          ")
    {% else %}
      # On LLVM < 9.0 using the previous code emits some additional
      # instructions that breaks the context switching.
      asm("
          pushq %rcx
          pushq %gs:0x10    // Thread Information Block: Stack Limit
          pushq %gs:0x08    // Thread Information Block: Stack Base
          pushq %rdi        // push 1st argument (because of initial resume)
          pushq %rbx        // push callee-saved registers on the stack
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
          movq %rsp, 0($0)  // current_context.stack_top = %rsp
          movl $$1, 8($0)   // current_context.resumable = 1
          movl $$0, 8($1)   // new_context.resumable = 0
          movq 0($1), %rsp  // %rsp = new_context.stack_top
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
          popq %rdi         // pop 1st argument (for initial resume)
          popq %gs:0x08
          popq %gs:0x10
          popq %rcx
          " :: "r"(current_context), "r"(new_context))
    {% end %}
  end
end
