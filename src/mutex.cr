# A fiber-safe mutex.
class Mutex
  @mutex_fiber : Fiber?
  @thread_mutex = Thread::Mutex.new

  def initialize
    @lock_count = 0
  end

  def lock
    @thread_mutex.lock
    mutex_fiber = @mutex_fiber
    current_fiber = Fiber.current

    if !mutex_fiber
      @mutex_fiber = current_fiber
      @thread_mutex.unlock
    elsif mutex_fiber == current_fiber
      @lock_count += 1 # recursive lock
      @thread_mutex.unlock
    else
      queue = @queue ||= Deque(Fiber).new
      current_fiber.append_callback ->{
        queue << current_fiber
        @thread_mutex.unlock
        nil
      }
      Scheduler.current.reschedule
    end

    nil
  end

  def unlock
    @thread_mutex.lock

    unless @mutex_fiber == Fiber.current
      @thread_mutex.unlock
      raise "Attempt to unlock a mutex which is not locked"
    end

    if @lock_count > 0
      @lock_count -= 1
      @thread_mutex.unlock
      return
    end

    if fiber = @queue.try &.shift?
      @mutex_fiber = fiber
      @thread_mutex.unlock
      Scheduler.current.enqueue fiber
    else
      @mutex_fiber = nil
      @thread_mutex.unlock
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
