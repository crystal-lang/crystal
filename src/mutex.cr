require "crystal/spin_lock"

# A fiber-safe mutex.
#
# By default the mutex is reentrant and can only be unlocked by the
# same fiber that locked it. This behaviour is enforced by some additional
# runtime checks.
#
# A non-reentrant mutex can be aquired only when unlocked and can lead
# to deadlocks if used recursively. A non-reentrant mutex is needed in more
# complex programs where the lock and unlock can happen in different fibers.
class Mutex
  @state = Atomic(Int32).new(0)
  @mutex_fiber : Fiber?
  @lock_count = 0
  @queue = Deque(Fiber).new
  @queue_count = Atomic(Int32).new(0)
  @lock = Crystal::SpinLock.new

  def initialize(*, @reentrant = true)
  end

  @[AlwaysInline]
  def lock
    if @state.swap(1) == 0
      @mutex_fiber = Fiber.current if @reentrant
      return
    end

    if @reentrant && @mutex_fiber == Fiber.current
      @lock_count += 1
      return
    end

    lock_slow
    nil
  end

  @[NoInline]
  private def lock_slow
    loop do
      break if try_lock

      @lock.sync do
        @queue_count.add(1)
        if @state.get == 0
          if @state.swap(1) == 0
            @queue_count.add(-1)
            @mutex_fiber = Fiber.current
            return
          end
        end

        @queue.push Fiber.current
      end
      Crystal::Scheduler.reschedule
    end

    @mutex_fiber = Fiber.current
    nil
  end

  private def try_lock
    i = 1000
    while @state.swap(1) != 0
      while @state.get != 0
        Intrinsics.pause
        i &-= 1
        return false if i == 0
      end
    end

    true
  end

  def unlock
    if @reentrant
      unless @mutex_fiber == Fiber.current
        raise "Attempt to unlock a mutex which is not locked"
      end

      if @lock_count > 0
        @lock_count -= 1
        return
      end

      @mutex_fiber = nil
    end

    @state.lazy_set(0)

    if @queue_count.get == 0
      return
    end

    fiber = nil
    @lock.sync do
      if @queue_count.get == 0
        return
      end

      if fiber = @queue.shift?
        @queue_count.add(-1)
      end
    end
    fiber.enqueue if fiber

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
