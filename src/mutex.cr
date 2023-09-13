require "crystal/spin_lock"

# A fiber-safe mutex.
#
# Provides deadlock protection by default. Attempting to re-lock the mutex from
# the same fiber will raise an exception. Trying to unlock an unlocked mutex, or
# a mutex locked by another fiber will raise an exception.
#
# The reentrant protection maintains a lock count. Attempting to re-lock the
# mutex from the same fiber will increment the lock count. Attempting to unlock
# the counter from the same fiber will decrement the lock count, eventually
# releasing the lock when the lock count returns to 0. Attempting to unlock an
# unlocked mutex, or a mutex locked by another fiber will raise an exception.
#
# You also disable all protections with `unchecked`. Attempting to re-lock the
# mutex from the same fiber will deadlock. Any fiber can unlock the mutex, even
# if it wasn't previously locked.
class Mutex
  @state = Atomic(Int32).new(0)
  @mutex_fiber : Fiber?
  @lock_count = 0
  @queue = Deque(Fiber).new
  @queue_count = Atomic(Int32).new(0)
  @lock = Crystal::SpinLock.new

  enum Protection
    Checked
    Reentrant
    Unchecked
  end

  def initialize(@protection : Protection = :checked)
  end

  @[AlwaysInline]
  def lock : Nil
    if @state.swap(1) == 0
      @mutex_fiber = Fiber.current unless @protection.unchecked?
      return
    end

    if !@protection.unchecked? && @mutex_fiber == Fiber.current
      if @protection.reentrant?
        @lock_count += 1
        return
      else
        raise "Attempt to lock a mutex recursively (deadlock)"
      end
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

  def unlock : Nil
    unless @protection.unchecked?
      if mutex_fiber = @mutex_fiber
        unless mutex_fiber == Fiber.current
          raise "Attempt to unlock a mutex locked by another fiber"
        end
      else
        raise "Attempt to unlock a mutex which is not locked"
      end

      if @protection.reentrant? && @lock_count > 0
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

  def synchronize(&)
    lock
    begin
      yield
    ensure
      unlock
    end
  end
end
