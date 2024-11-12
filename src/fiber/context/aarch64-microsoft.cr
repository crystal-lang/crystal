{% skip_file unless flag?(:aarch64) && flag?(:win32) %}

class Fiber
  # :nodoc:
  def makecontext(stack_ptr, fiber_main) : Nil
    # ARM64 Windows also follows the AAPCS64 for the most part, except extra
    # bookkeeping information needs to be kept in the Thread Information Block,
    # referenceable from the x18 register

    # 12 general-purpose registers + 8 FPU registers + 1 parameter + 3 qwords for NT_TIB
    @context.stack_top = (stack_ptr - 24).as(Void*)
    @context.resumable = 1

    # actual stack top, not including guard pages and reserved pages
    LibC.GetNativeSystemInfo(out system_info)
    stack_top = @stack_bottom - system_info.dwPageSize

    stack_ptr[-4] = self.as(Void*)      # x0 (r0): puts `self` as first argument for `fiber_main`
    stack_ptr[-16] = fiber_main.pointer # x30 (lr): initial `resume` will `ret` to this address

    # The following three values are stored in the Thread Information Block (NT_TIB)
    # and are used by Windows to track the current stack limits
    stack_ptr[-3] = @stack        # [x18, #0x1478]: Win32 DeallocationStack
    stack_ptr[-2] = stack_top     # [x18, #16]: Stack Limit
    stack_ptr[-1] = @stack_bottom # [x18, #8]: Stack Base
  end

  # :nodoc:
  @[NoInline]
  @[Naked]
  def self.swapcontext(current_context, new_context) : Nil
    #                  x0             , x1

    # see also `./aarch64-generic.cr`
    {% if compare_versions(Crystal::LLVM_VERSION, "9.0.0") >= 0 %}
      asm("
      stp     d15, d14, [sp, #-24*8]!
      stp     d13, d12, [sp, #2*8]
      stp     d11, d10, [sp, #4*8]
      stp     d9,  d8,  [sp, #6*8]
      stp     x30, x29, [sp, #8*8]  // lr, fp
      stp     x28, x27, [sp, #10*8]
      stp     x26, x25, [sp, #12*8]
      stp     x24, x23, [sp, #14*8]
      stp     x22, x21, [sp, #16*8]
      stp     x20, x19, [sp, #18*8]
      str     x0,       [sp, #20*8] // push 1st argument

      ldr     x19, [x18, #0x1478]   // Thread Information Block: Win32 DeallocationStack
      str     x19, [sp, #21*8]
      ldr     x19, [x18, #16]       // Thread Information Block: Stack Limit
      str     x19, [sp, #22*8]
      ldr     x19, [x18, #8]        // Thread Information Block: Stack Base
      str     x19, [sp, #23*8]

      mov     x19, sp               // current_context.stack_top = sp
      str     x19, [x0, #0]
      mov     x19, #1               // current_context.resumable = 1
      str     x19, [x0, #8]

      mov     x19, #0               // new_context.resumable = 0
      str     x19, [x1, #8]
      ldr     x19, [x1, #0]         // sp = new_context.stack_top (x19)
      mov     sp, x19

      ldr     x19, [sp, #23*8]
      str     x19, [x18, #8]
      ldr     x19, [sp, #22*8]
      str     x19, [x18, #16]
      ldr     x19, [sp, #21*8]
      str     x19, [x18, #0x1478]

      ldr     x0,       [sp, #20*8] // pop 1st argument (+ alignment)
      ldp     x20, x19, [sp, #18*8]
      ldp     x22, x21, [sp, #16*8]
      ldp     x24, x23, [sp, #14*8]
      ldp     x26, x25, [sp, #12*8]
      ldp     x28, x27, [sp, #10*8]
      ldp     x30, x29, [sp, #8*8]  // lr, fp
      ldp     d9,  d8,  [sp, #6*8]
      ldp     d11, d10, [sp, #4*8]
      ldp     d13, d12, [sp, #2*8]
      ldp     d15, d14, [sp], #24*8

      // avoid a stack corruption that will confuse the unwinder
      mov     x16, x30 // save lr
      mov     x30, #0  // reset lr
      br      x16      // jump to new pc value
      ")
    {% else %}
      # On LLVM < 9.0 using the previous code emits some additional
      # instructions that breaks the context switching.
      asm("
      stp     d15, d14, [sp, #-24*8]!
      stp     d13, d12, [sp, #2*8]
      stp     d11, d10, [sp, #4*8]
      stp     d9,  d8,  [sp, #6*8]
      stp     x30, x29, [sp, #8*8]  // lr, fp
      stp     x28, x27, [sp, #10*8]
      stp     x26, x25, [sp, #12*8]
      stp     x24, x23, [sp, #14*8]
      stp     x22, x21, [sp, #16*8]
      stp     x20, x19, [sp, #18*8]
      str     x0,       [sp, #20*8] // push 1st argument

      ldr     x19, [x18, #0x1478]   // Thread Information Block: Win32 DeallocationStack
      str     x19, [sp, #21*8]
      ldr     x19, [x18, #16]       // Thread Information Block: Stack Limit
      str     x19, [sp, #22*8]
      ldr     x19, [x18, #8]        // Thread Information Block: Stack Base
      str     x19, [sp, #23*8]

      mov     x19, sp               // current_context.stack_top = sp
      str     x19, [$0, #0]
      mov     x19, #1               // current_context.resumable = 1
      str     x19, [$0, #8]

      mov     x19, #0               // new_context.resumable = 0
      str     x19, [$1, #8]
      ldr     x19, [$1, #0]         // sp = new_context.stack_top (x19)
      mov     sp, x19

      ldr     x19, [sp, #23*8]
      str     x19, [x18, #8]
      ldr     x19, [sp, #22*8]
      str     x19, [x18, #16]
      ldr     x19, [sp, #21*8]
      str     x19, [x18, #0x1478]

      ldr     x0,       [sp, #20*8] // pop 1st argument (+ alignment)
      ldp     x20, x19, [sp, #18*8]
      ldp     x22, x21, [sp, #16*8]
      ldp     x24, x23, [sp, #14*8]
      ldp     x26, x25, [sp, #12*8]
      ldp     x28, x27, [sp, #10*8]
      ldp     x30, x29, [sp, #8*8]  // lr, fp
      ldp     d9,  d8,  [sp, #6*8]
      ldp     d11, d10, [sp, #4*8]
      ldp     d13, d12, [sp, #2*8]
      ldp     d15, d14, [sp], #24*8

      // avoid a stack corruption that will confuse the unwinder
      mov     x16, x30 // save lr
      mov     x30, #0  // reset lr
      br      x16      // jump to new pc value
      " :: "r"(current_context), "r"(new_context))
    {% end %}
  end
end
