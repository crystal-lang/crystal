{% skip_file if flag?(:interpreted) %}

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

  class TestTimeout
    def initialize(@timeout : Time::Span = 2.seconds)
      @start = Time.monotonic
      @cancelled = Atomic(Bool).new(false)
    end

    def cancel : Nil
      @cancelled.set(true)
    end

    def elapsed?
      (Time.monotonic - @start) >= @timeout
    end

    def done?
      return true if @cancelled.get
      raise "timeout reached" if elapsed?
      false
    end

    def sleep(interval = 100.milliseconds) : Nil
      until done?
        ::sleep interval
      end
    end

    def reset : Nil
      @start = Time.monotonic
      @cancelled.set(false)
    end
  end
end
