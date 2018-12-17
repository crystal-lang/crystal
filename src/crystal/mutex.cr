require "./spin_lock"
require "./wait_queue"

# :nodoc:
#
# A fiber-aware mutual exclusion lock, without extra checks (any fiber can
# unlock the mutex) and less features (no recursive locks).
class Crystal::Mutex
  def initialize
    @held = Atomic::Flag.new
    @spin = Crystal::SpinLock.new
    @blocking = Crystal::WaitQueue.new
  end

  def lock : Nil
    # try to acquire lock (without spin lock):
    return if try_lock

    current = Fiber.current

    # need exclusive access to re-check @held then manipulate @blocking
    # based on the CAS result:
    @spin.lock

    # must loop because a wakeup may be concurrential (e.g.
    # `ConditionVariable#broadcast`) and another `#lock` or `#try_lock` already
    # acquired the lock:
    until @held.test_and_set
      @blocking.push(current)

      # release exclusive access while current fiber is suspended:
      @spin.unlock

      Crystal::Scheduler.reschedule

      # re-acquire exclusive access when resumed:
      @spin.lock
    end

    @spin.unlock
  end

  def try_lock : Bool
    # try to acquire the lock, without exclusive access because we don't
    # manipulate @blocking based on @held result:
    @held.test_and_set
  end

  def unlock : Nil
    # need exclusive access because we modify both @held and @blocking:
    @spin.lock

    # removes the lock (assumes the current fiber holds the lock):
    @held.clear

    # wakeup next blocked fiber (if any):
    if fiber = @blocking.shift?
      @spin.unlock
      Crystal::Scheduler.yield(fiber)
    else
      @spin.unlock
    end
  end
end
