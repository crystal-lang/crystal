{% skip_file unless flag?(:interpreted) %}

require "crystal/interpreter"

class Fiber
  # :nodoc:
  def makecontext(stack_ptr, fiber_main) : Nil
    # In interpreted mode the stack_top variable actually points to the actual
    # fiber running on the interpreter
    @context.stack_top = Crystal::Interpreter.spawn(self, fiber_main.pointer)
  end

  # :nodoc:
  @[Primitive(:interpreter_fiber_swapcontext)]
  def self.swapcontext(current_context, new_context) : Nil
  end
end
