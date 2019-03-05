# :nodoc:
#
# A FIFO queue of pending fibers implemented as a singly-linked list.
#
# Assumes that a `Fiber` can only be in a single `WaitQueue`, `WaitDeque` or
# `Scheduler::Runnables` at a time, during which its execution will be
# suspended.
#
# The queue is fiber and thread unsafe. Accesses must be synchronized using
# another mean, for example `Thread::Mutex` or `Crystal::SpinLock`.
struct Crystal::WaitQueue
  @head : Fiber?
  @tail : Fiber?

  def push(fiber : Fiber) : Nil
    fiber.queue_next = nil

    if @head
      @tail = @tail.as(Fiber).queue_next = fiber
    else
      @tail = @head = fiber
    end
  end

  def shift? : Fiber?
    if fiber = @head
      @head = fiber.queue_next
      fiber
    end
  end

  def each : Nil
    fiber = @head

    while fiber
      # avoid issues if fiber is queued somewhere else during the block call by
      # memorizing the next fiber to iterate:
      next_fiber = fiber.queue_next
      yield fiber
      fiber = next_fiber
    end
  end

  def clear : Nil
    @head = nil
  end
end
