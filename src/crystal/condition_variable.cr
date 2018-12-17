require "./mutex"

# :nodoc:
#
# A fiber-aware monitor for synchronizing mutually exclusive locks
# (`Crystal::Mutex`).
class Crystal::ConditionVariable
  def initialize
    @spin = Crystal::SpinLock.new
    @waiting = Crystal::WaitQueue.new
  end

  # Puts the current fiber into a waiting state, releasing *mutex* until the
  # condition variable is signaled or broadcasted. Locks the mutex again before
  # returning.
  def wait(mutex : Crystal::Mutex) : Nil
    current = Fiber.current

    # queue current fiber into wait list:
    @spin.lock
    @waiting.push(current)
    @spin.unlock

    # release mutex lock, enqueueing a blocked fiber —must always succeed
    # because current fiber holds the lock:
    mutex.unlock

    # suspend execution of current fiber:
    Crystal::Scheduler.reschedule

    # must re-acquire the mutex lock to continue:
    mutex.lock
  end

  # Resumes a single waiting fiber. Does nothing if the waitlist is empty.
  def signal : Nil
    @spin.lock

    # enqueue next waiting fiber (if any):
    if fiber = @waiting.shift?
      @spin.unlock
      Crystal::Scheduler.enqueue(fiber)
    else
      @spin.unlock
    end
  end

  # Resumes all waiting fibers. Does nothing if the waitlist is empty.
  def broadcast : Nil
    @spin.lock
    @waiting.each do |fiber|
      Crystal::Scheduler.enqueue(fiber)
    end
    @waiting.clear
    @spin.unlock
  end
end
