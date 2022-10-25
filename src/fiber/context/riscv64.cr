{% skip_file unless flag?(:riscv64) %}

class Fiber
  # :nodoc:
  def makecontext(stack_ptr, fiber_main) : Nil
    # in riscv64, the context switch push/pop 12 registers
    # that is left on the stack, we thus reserve space for 12 pointers:
    @context.stack_top = (stack_ptr - 12).as(Void*)
    @context.resumable = 1

    stack_ptr[-1] = fiber_main.pointer # x1 (ra): initial `resume` will `ret` to this address
    stack_ptr[-13] = self.as(Void*)    # puts `self` as first argument for `fiber_main`
  end

  # :nodoc:
  @[NoInline]
  @[Naked]
  def self.swapcontext(current_context, new_context) : Nil
    #                  a0,              a1
    {% if compare_versions(Crystal::LLVM_VERSION, "9.0.0") >= 0 %}
      # adapted from https://sourceware.org/git/?p=glibc.git;a=blob_plain;f=sysdeps/unix/sysv/linux/riscv/swapcontext.S;hb=HEAD
      asm("
      sd s0, 16(a0)  // push callee-saved registers on the stack
      sd s1, 24(a0)
      sd s2, 32(a0)
      sd s3, 40(a0)
      sd s4, 48(a0)
      sd s5, 56(a0)
      sd s6, 64(a0)
      sd s7, 72(a0)
      sd s8, 80(a0)
      sd s9, 88(a0)
      sd s10, 96(a0)
      sd s11, 104(a0)

      frsr a1

      fsd fs0, 16(a0)  // push callee-saved registers on the stack
      fsd fs1, 24(a0)
      fsd fs2, 32(a0)
      fsd fs3, 40(a0)
      fsd fs4, 48(a0)
      fsd fs5, 56(a0)
      fsd fs6, 64(a0)
      fsd fs7, 72(a0)
      fsd fs8, 80(a0)
      fsd fs9, 88(a0)
      fsd fs10, 96(a0)
      fsd fs11, 104(a0)

      sd sp, 0(a0)   // current_context.stack_top = sp
      addi t1, x0, 1
      ld t1, 8(a0)   // current_context.resumable = 1

      sd x0, 8(a0)   // new_context.resumable = 0
      ld sp, 0(a0)   // sp = new_context.stack_top

      fld fs0, 16(a1)  // pop callee-saved registers from the stack
      fld fs1, 24(a1)
      fld fs2, 32(a1)
      fld fs3, 40(a1)
      fld fs4, 48(a1)
      fld fs5, 56(a1)
      fld fs6, 64(a1)
      fld fs7, 72(a1)
      fld fs8, 80(a1)
      fld fs9, 88(a1)
      fld fs10, 96(a1)
      fld fs11, 104(a1)

      fssr a1

      ld s0, 16(a1)
      ld s1, 24(a1)
      ld s2, 32(a1)
      ld s3, 40(a1)
      ld s4, 48(a1)
      ld s5, 56(a1)
      ld s6, 64(a1)
      ld s7, 72(a1)
      ld s8, 80(a1)
      ld s9, 88(a1)
      ld s10, 96(a1)
      ld s11, 104(a1)
      ")
    {% else %}
      # Since 9.0, LLVM start to fully support RISC-V
      raise "RISC-V is only fully supported since LLVM 9"
    {% end %}
  end
end
