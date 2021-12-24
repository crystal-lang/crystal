class Fiber
  # :nodoc:
  #
  # The arch-specific make/swapcontext assembly relies on the Context struct and
  # expects the following layout. Avoid moving the struct properties as it would
  # require to update all the make/swapcontext implementations.
  @[Extern]
  struct Context
    property stack_top : Void*
    property resumable : LibC::Long

    def initialize(@stack_top = Pointer(Void).null)
      @resumable = 0
    end
  end

  # :nodoc:
  #
  # A fiber context switch in Crystal is achieved by calling a symbol (which
  # must never be inlined) that will push the callee-saved registers (sometimes
  # FPU registers and others) on the stack, saving the current stack pointer at
  # location pointed by `current_stack_ptr` (the current fiber is now paused)
  # then loading the `dest_stack_ptr` pointer into the stack pointer register
  # and popping previously saved registers from the stack. Upon return from the
  # symbol the new fiber is resumed since we returned/jumped to the calling
  # symbol.
  #
  # Details are arch-specific. For example:
  # - which registers must be saved, the callee-saved are sometimes enough (X86)
  #   but some archs need to save the FPU register too (ARMHF);
  # - a simple return may be enough (X86), but sometimes an explicit jump is
  #   required to not confuse the stack unwinder (ARM);
  # - and more.
  #
  # For the initial resume, the register holding the first parameter must be set
  # (see makecontext below) and thus must also be saved/restored when swapping
  # the context.
  #
  # def self.swapcontext(current_context : Context*, new_context : Context*) : Nil
  # end

  # :nodoc:
  #
  # Initializes `@context`, reserves and initializes space on the stack for the
  # initial context that must call the *fiber_main* proc, passing `self` as its
  # first argument.
  #
  # def makecontext(stack_ptr : Void*, fiber_main : Fiber ->) : Nil
  # end
end

# Load the arch-specific methods to create a context and to swap from one
# context to another one. There are two methods: `Fiber#makecontext` and
# `Fiber.swapcontext`.
{% if flag?(:interpreted) %}
  require "./context/interpreted"
{% else %}
  require "./context/*"
{% end %}
