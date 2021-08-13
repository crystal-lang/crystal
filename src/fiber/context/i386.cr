{% skip_file unless flag?(:i386) %}

class Fiber
  # :nodoc:
  def makecontext(stack_ptr, fiber_main)
    # in IA32 (x86), the context switch push/pop 4 registers, and we need two
    # more to store the argument for `fiber_main` and keep the stack aligned on
    # 16 bytes, we thus reserve space for 6 pointers:
    @context.stack_top = (stack_ptr - 6).as(Void*)
    @context.resumable = 1

    stack_ptr[0] = self.as(Void*)      # first argument passed on the stack
    stack_ptr[-1] = Pointer(Void).null # empty space to keep the stack alignment (16 bytes)
    stack_ptr[-2] = fiber_main.pointer # initial `resume` will `ret` to this address
  end

  # :nodoc:
  @[NoInline]
  @[Naked]
  def self.swapcontext(current_context, new_context) : Nil
    {% if compare_versions(Crystal::LLVM_VERSION, "9.0.0") >= 0 %}
      #                %ecx           , %eax
      asm("
      movl 8(%esp), %eax
      movl 4(%esp), %ecx
      pushl %edi        // push 1st argument (because of initial resume)
      pushl %ebx        // push callee-saved registers on the stack
      pushl %ebp
      pushl %esi
      movl %esp, 0(%ecx)  // current_context.stack_top = %esp
      movl $$1, 4(%ecx)   // current_context.resumable = 1

      movl $$0, 4(%eax)   // new_context.resumable = 0
      movl 0(%eax), %esp  // %esp = new_context.stack_top
      popl %esi         // pop callee-saved registers from the stack
      popl %ebp
      popl %ebx
      popl %edi         // pop first argument (for initial resume)
      ")
    {% else %}
      # On LLVM < 9.0 using the previous code emits some additional
      # instructions that breaks the context switching.
      asm("
      pushl %edi        // push 1st argument (because of initial resume)
      pushl %ebx        // push callee-saved registers on the stack
      pushl %ebp
      pushl %esi
      movl %esp, 0($0)  // current_context.stack_top = %esp
      movl $$1, 4($0)   // current_context.resumable = 1

      movl $$0, 4($1)   // new_context.resumable = 0
      movl 0($1), %esp  // %esp = new_context.stack_top
      popl %esi         // pop callee-saved registers from the stack
      popl %ebp
      popl %ebx
      popl %edi         // pop first argument (for initial resume)
      " :: "r"(current_context), "r"(new_context))
    {% end %}
  end
end
