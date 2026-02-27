require "./parallel"

module Fiber::ExecutionContext
  # Concurrent-only execution context.
  #
  # Fibers running in the same context can only run concurrently and never in
  # parallel to each others. However, they still run in parallel to fibers
  # running in other execution contexts.
  #
  # Fibers in this context can use simpler and faster synchronization primitives
  # between themselves (for example no atomics or thread safety required), but
  # data shared with other contexts needs to be protected (see `Sync`), and
  # communication with fibers in other contexts requires safe primitives, for
  # example `Channel`.
  #
  # A blocking fiber blocks the entire context, and thus all the other fibers in
  # the context.
  #
  # For example: we can start a concurrent context to run consumer fibers, while
  # the default context produces values. Because the consumer fibers will never
  # run in parallel and don't yield between reading *result* then writing it, we
  # are not required to synchronize accesses to the value:
  #
  # ```
  # require "wait_group"
  #
  # consumers = Fiber::ExecutionContext::Concurrent.new("consumers")
  # channel = Channel(Int32).new(64)
  # wg = WaitGroup.new(32)
  #
  # result = 0
  #
  # 32.times do
  #   consumers.spawn do
  #     while value = channel.receive?
  #       # safe, but only for this example:
  #       result = result + value
  #     end
  #   ensure
  #     wg.done
  #   end
  # end
  #
  # 1024.times { |i| channel.send(i) }
  # channel.close
  #
  # # wait for all workers to be done
  # wg.wait
  #
  # p result # => 523776
  # ```
  #
  # In practice, we still recommended to always protect shared accesses to a
  # variable, for example using `Atomic#add` to increment *result* or a `Sync`
  # primitive for more complex operations.
  class Concurrent < Parallel
    # :nodoc:
    def self.default : self
      new("DEFAULT", capacity: 1, hijack: true)
    end

    # Creates a `Concurrent` context. The context will only really start when a
    # fiber is spawned into it.
    def self.new(name : String) : self
      new(name, capacity: 1, hijack: false)
    end

    # Always raises an `ArgumentError` exception because a concurrent context
    # cannot be resized.
    def resize(maximum : Int32) : Nil
      raise ArgumentError.new("Can't resize a concurrent context")
    end
  end

  @[Deprecated("Use Fiber::ExecutionContext::Concurrent instead.")]
  alias SingleThreaded = Concurrent
end
