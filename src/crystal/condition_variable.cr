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
    @spin.synchronize { @waiting.push(current) }

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
    # enqueue next waiting fiber (if any):
    if fiber = @spin.synchronize { @waiting.shift? }
      Crystal::Scheduler.enqueue(fiber)
    end
  end

  # Resumes all waiting fibers. Does nothing if the waitlist is empty.
  def broadcast : Nil
    @spin.synchronize do
      @waiting.each { |fiber| Crystal::Scheduler.enqueue(fiber) }
      @waiting.clear
    end
  end
end
