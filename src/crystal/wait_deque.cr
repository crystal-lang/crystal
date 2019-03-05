require "./spin_lock"

# :nodoc:
#
# A double-ended queue of pending fibers implemented as a doubly-linked list.
#
# Assumes that a `Fiber` can only be in a single `WaitQueue`, `WaitDeque` or
# `Scheduler::Runnables` at a time, during which its execution will be
# suspended.
#
# The queue is fiber and thread unsafe. Accesses must be synchronized using
# another mean, for example `Thread::Mutex` or `Crystal::SpinLock`.
struct Crystal::WaitDeque
  @head : Fiber?
  @tail : Fiber?
  @spin = Crystal::SpinLock.new

  def unshift(fiber : Fiber) : Nil
    @spin.synchronize do
      fiber.queue_prev = nil

      if head = @head
        fiber.queue_next = head
        @head = head.queue_prev = fiber
      else
        fiber.queue_next = nil
        @head = @tail = fiber
      end
    end
  end

  def push(fiber : Fiber) : Nil
    @spin.synchronize do
      fiber.queue_next = nil

      if tail = @tail
        fiber.queue_prev = tail
        @tail = tail.queue_next = fiber
      else
        fiber.queue_prev = nil
        @head = @tail = fiber
      end
    end
  end

  def <<(fiber)
    push fiber
  end

  def shift? : Nil
    @spin.synchronize do
      return unless fiber = @head

      if new_head = fiber.queue_next
        new_head.queue_prev = nil
        @head = new_head
      else
        @head = @tail = nil
      end

      fiber
    end
  end

  def pop? : Nil
    @spin.synchronize do
      return unless fiber = @tail

      if new_tail = fiber.queue_prev
        new_tail.queue_next = nil
        @tail = new_tail
      else
        @head = @tail = nil
      end

      fiber
    end
  end

  def delete(fiber : Fiber) : Nil
    @spin.synchronize do
      prev_fiber = fiber.queue_prev
      next_fiber = fiber.queue_next

      if prev_fiber
        prev_fiber.queue_next = next_fiber
      else
        @head = next_fiber
      end

      if next_fiber
        next_fiber.queue_prev = prev_fiber
      else
        @tail = prev_fiber
      end
    end
  end

  def clear : self
    @spin.synchronize do
      copy = dup
      @head = @tail = nil
      copy
    end
  end

  def unsafe_each : Nil
    fiber = @head

    while fiber
      # avoid issues if fiber is queued somewhere else during the iteration by
      # memorizing the next fiber to iterate:
      next_fiber = fiber.queue_next
      yield fiber
      fiber = next_fiber
    end
  end
end
