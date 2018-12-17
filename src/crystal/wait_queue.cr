# :nodoc:
#
# A linked-list of pending fibers. Assumes that a fiber can only be in a
# single wait queue at a time, during which its execution is suspended.
#
# The linked-list is fiber and thread unsafe. Accesses must be synchronized
# using another mean, usually `Crystal::SpinLock`.
struct Crystal::WaitQueue
  @head : Fiber?
  @tail : Fiber?

  def push(fiber : Fiber) : Nil
    fiber.mutex_next = nil

    if @head
      @tail = @tail.not_nil!.mutex_next = fiber
    else
      @tail = @head = fiber
    end
  end

  def shift? : Fiber?
    if fiber = @head
      @head = fiber.mutex_next
      fiber
    end
  end

  def each : Nil
    fiber = @head

    while fiber
      yield fiber
      fiber = fiber.mutex_next
    end
  end

  def clear : Nil
    @head = nil
  end
end
