require "fiber"
require "crystal/spin_lock"
require "crystal/pointer_linked_list"

# Suspend execution until a collection of fibers are finished.
#
# The wait group is a declarative counter of how many concurrent fibers have
# been started. Each such fiber is expected to call `#done` to report that hey
# are finished doing their work. Whenever the counter reaches zero the waiters
# will be resumed.
#
# This is a simpler and more efficient alternative to using a `Channel(Nil)`
# then looping a number of times until we received N messages to resume
# execution.
#
# Basic example:
#
# ```
# require "wait_group"
# wg = WaitGroup.new(5)
#
# 5.times do
#   spawn do
#     do_something
#   ensure
#     wg.done # the fiber has finished
#   end
# end
#
# # suspend the current fiber until the 5 fibers are done
# wg.wait
# ```
class WaitGroup
  private struct Waiting
    include Crystal::PointerLinkedList::Node

    def initialize(@fiber : Fiber)
    end

    def enqueue : Nil
      @fiber.enqueue
    end
  end

  def initialize(n : Int32 = 0)
    @waiting = Crystal::PointerLinkedList(Waiting).new
    @lock = Crystal::SpinLock.new
    @counter = Atomic(Int32).new(n)
  end

  # Increments the counter by how many fibers we want to wait for.
  #
  # This can also be used to decrement the counter, in which case the behavior
  # is identical to `#done`.
  #
  # Can be called at any time, allowing concurrent fibers to add more fibers to
  # wait for, but they must always do so before calling `#done` that would
  # decrement the counter, to make sure that the counter may never inadvertently
  # reach zero before all fibers are done.
  def add(n : Int32 = 1) : Nil
    new_value = @counter.add(n) + n
    raise "Negative WaitGroup counter" if new_value < 0
    return unless new_value == 0

    @lock.sync do
      @waiting.consume_each do |node|
        node.value.enqueue
      end
    end
  end

  # Decrements the counter by one. Must be called by concurrent fibers once they
  # have finished processing. When the counter reaches zero, all waiting fibers
  # will be resumed.
  def done : Nil
    add(-1)
  end

  # Suspends the current fiber until the counter reaches zero, at which point
  # the fiber will be resumed.
  #
  # Can be called from different fibers.
  def wait : Nil
    return if @counter.get == 0
    waiting = Waiting.new(Fiber.current)

    @lock.sync do
      # must check again to avoid a race condition where #done may have
      # decremented the counter to zero between the above check and #wait
      # acquiring the lock; we'd push the current fiber to the wait list that
      # would never be resumed (oops)
      return if @counter.get == 0

      @waiting.push(pointerof(waiting))
    end

    Crystal::Scheduler.reschedule
  end
end
