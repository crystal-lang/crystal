{% skip_file unless flag?(:wasm32) %}

class Fiber
  # :nodoc:
  def makecontext(stack_ptr, fiber_main)
    # TODO: Implement this using Binaryen Asyncify
  end

  # :nodoc:
  @[NoInline]
  @[Naked]
  def self.swapcontext(current_context, new_context) : Nil
    # TODO: Implement this using Binaryen Asyncify
  end
end
