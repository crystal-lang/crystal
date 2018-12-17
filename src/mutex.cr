require "crystal/mutex"

# A fiber-aware mutual exclusion lock.
class Mutex
  @mutex_fiber : Fiber?

  def initialize
    @mutex = Crystal::Mutex.new
    @lock_count = 0
  end

  # Locks the mutex, blocking the current fiber until the lock is acquired.
  def lock : Nil
    current = Fiber.current

    if @mutex_fiber == current
      @lock_count += 1
    else
      @mutex.lock
      @mutex_fiber = current
    end
  end

  # Try to lock the mutex. Returns immediately with `true` if the lock was
  # acquired and `false` otherwise.
  def try_lock : Bool
    @mutex.try_lock
  end

  # Unlocks the mutex lock. Resumes a blocked fiber if one is pending.
  def unlock : Nil
    unless @mutex_fiber == Fiber.current
      raise "Attempt to unlock a mutex which is not locked"
    end

    if @lock_count > 0
      @lock_count -= 1
    else
      @mutex_fiber = nil
      @mutex.unlock
    end
  end

  # Locks the mutex, executes the block (aka the critical section) and
  # eventually unlocks the mutex before returning.
  #
  # The block is guaranteed to never be executed concurrently.
  def synchronize
    lock
    begin
      yield
    ensure
      unlock
    end
  end
end
