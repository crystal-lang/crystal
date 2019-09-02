require "crystal/spin_lock"

# A fiber-safe mutex.
class Mutex
  @mutex_fiber : Fiber?
  @lock_count = 0
  @queue = Deque(Fiber).new
  @lock = Crystal::SpinLock.new

  def lock
    @lock.lock
    mutex_fiber = @mutex_fiber
    current_fiber = Fiber.current

    if !mutex_fiber
      @mutex_fiber = current_fiber
      @lock.unlock
    elsif mutex_fiber == current_fiber
      @lock_count += 1 # recursive lock
      @lock.unlock
    else
      @queue << current_fiber
      @lock.unlock
      Crystal::Scheduler.reschedule
    end

    nil
  end

  def unlock
    @lock.lock

    begin
      unless @mutex_fiber == Fiber.current
        raise "Attempt to unlock a mutex which is not locked"
      end

      if @lock_count > 0
        @lock_count -= 1
        return
      end

      if fiber = @queue.try &.shift?
        @mutex_fiber = fiber
        fiber.enqueue
      else
        @mutex_fiber = nil
      end
    ensure
      @lock.unlock
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
