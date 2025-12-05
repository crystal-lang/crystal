require "./cv"
require "./lockable"

module Sync
  # Suspend a fiber until notified.
  #
  # A `ConditionVariable` can be associated to any `Lockable`.
  #
  # While one `Lockable` can be associated to multiple `ConditionVariable`, one
  # `ConditionVariable` can only be associated to a single `Lockable`
  # (one-to-many relation).
  class ConditionVariable
    def initialize(@lock : Lockable)
      @cv = CV.new
    end

    # Blocks the calling fiber until the condition variable is signaled.
    #
    # The *lock* must be held upon calling. Releases *lock* before waiting, so
    # any other fiber can acquire the lock while the calling fiber is waiting.
    # The lock is re-acquired before returning.
    #
    # A `RWLock` and `Shared(T)` can be held in either read or write mode, the
    # lock will be reacquired in the same mode (read or write) before returning.
    #
    # The calling fiber will be woken by `#signal` or `#broadcast`.
    def wait : Nil
      # delegate to lockable so it can run pre-unlock checks and cleanup, then
      # reset after-lock values (locked by, reentrant counter)
      @lock.wait pointerof(@cv)
    end

    # Wakes up one waiting fiber.
    #
    # For `RWLock` and `Shared(T)` all readers can acquire, thus multiple
    # readers might be woken at once, but only one writer can acquire, thus only
    # one reader will be woken at a time.
    #
    # You can wake all waiting fibers with `#broadcast`.
    def signal : Nil
      @cv.signal
    end

    # Wakes up all waiting fibers at once.
    #
    # You can wake a single waiting fiber with `#signal`.
    def broadcast : Nil
      @cv.broadcast
    end

    # :nodoc:
    def dup
      {% raise "Can't dup {{@type}}" %}
    end
  end
end
