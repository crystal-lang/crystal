require "../../spec_helper"
require "../../../support/fibers"
require "crystal/system/thread_wait_group"
require "fiber/execution_context/runnables"
require "fiber/execution_context/global_queue"

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

  # Runs a multithreaded test by starting *n* threads, waiting for all the
  # threads to have been started the *publish* proc.
  #
  # Each thread calls *iteration* until the timeout is reached or the proc
  # returns `:break`; if the proc returns `:next` the thread goes immediately to
  # the next iteration, other it will ease the CPU before the next iteration.
  #
  # Returns after every thread has been joined.
  def self.stress_test(n, *, iteration, publish, name = "STRESS", timeout = 1.second)
    ready = Thread::WaitGroup.new(n)

    threads = Array.new(n) do |i|
      new_thread("#{name}-#{i}") do
        ready.done

        started = Time.monotonic
        attempts = 0

        iter = 0
        while iter += 1
          if iter % 100 == 99 && (Time.monotonic - started) >= timeout
            # reached timeout: abort
            break
          end

          case iteration.call(i)
          when :next
            attempts = 0
            next
          when :break
            break
          else
            # don't burn CPU
            attempts = Thread.delay(attempts)
          end
        end
      end
    end

    ready.wait(timeout * 2) do
      raise "timeout while waiting for threads to be ready"
    end

    publish.call

    threads.each(&.join)
  end
end
