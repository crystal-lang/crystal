module Sync
  # Raised when a sync check fails. For example when trying to unlock an
  # unlocked mutex. See `#message` for details.
  class Error < Exception
    # Raised when a lock would result in a deadlock. For example when trying to
    # re-lock a checked mutex.
    class Deadlock < Error
      getter fiber1 : Fiber?
      getter fiber2 : Fiber?

      getter lock1 : Mutex | RWLock | Nil
      getter lock2 : Mutex | RWLock | Nil

      def initialize(message : String, @fiber1 = nil, @fiber2 = nil, @lock1 = nil, @lock2 = nil)
        super(message)
      end
    end
  end
end
