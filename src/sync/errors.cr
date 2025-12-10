module Sync
  # Raised when a sync check fails. For example when trying to unlock an
  # unlocked mutex. See `#message` for details.
  class Error < Exception
    # Raised when a lock would result in a deadlock. For example when trying to
    # re-lock a checked mutex.
    class Deadlock < Error
    end
  end
end
