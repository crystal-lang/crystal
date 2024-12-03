require "../spec_helper"
require "crystal/system/thread_wait_group"
require "execution_context/runnables"
require "execution_context/global_queue"

module ExecutionContext
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
