require "../../spec_helper"
require "crystal/system/thread_wait_group"
require "fiber/execution_context/runnables"
require "fiber/execution_context/global_queue"

# fake stack for `makecontext` to have somewhere to write in #initialize.
# we don't actually run the fiber.
FAKE_FIBER_STACK = GC.malloc(32)

def new_fake_fiber(name = nil)
  stack = FAKE_FIBER_STACK
  stack_bottom = FAKE_FIBER_STACK + 32

  {% if flag?(:execution_context) %}
    execution_context = Fiber::ExecutionContext.current
    Fiber.new(name, stack, stack_bottom, execution_context) { }
  {% else %}
    Fiber.new(name, stack, stack_bottom) { }
  {% end %}
end

module Fiber::ExecutionContext
  class FiberCounter
    def initialize(@fiber : Fiber)
      @counter = Atomic(Int32).new(0)
    end

    # fetch and add
    def increment
      @counter.add(1, :relaxed) + 1
    end

    def counter
      @counter.get(:relaxed)
    end
  end
end
