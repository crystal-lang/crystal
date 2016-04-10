# A fiber-safe mutex.
#
# TODO: this isn't thread-safe yet.
class Mutex
  @mutex_fiber : Fiber?

  def initialize
    @lock_count = 0
  end

  def lock
    mutex_fiber = @mutex_fiber
    current_fiber = Fiber.current

    if !mutex_fiber
      @mutex_fiber = current_fiber
    elsif mutex_fiber == current_fiber
      @lock_count += 1 # recursive lock
    else
      queue = @queue ||= Deque(Fiber).new
      queue << current_fiber
      Scheduler.reschedule
    end

    nil
  end

  def unlock
    unless @mutex_fiber == Fiber.current
      raise "Attempt to unlock a mutex which is not locked"
    end

    if @lock_count > 0
      @lock_count -= 1
      return
    end

    if fiber = @queue.try &.shift?
      @mutex_fiber = fiber
      Scheduler.enqueue fiber
    else
      @mutex_fiber = nil
    end

    nil
  end

  def synchronize
    lock
    begin
      yield
    ensure
      unlock
    end
  end
end
