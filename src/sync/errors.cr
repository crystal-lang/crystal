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

    # :nodoc:
    def self.deadlock(fiber, lock)
      type =
        case lock
        in Mutex
          "mutex"
        in RWLock
          "rwlock"
        end
      Deadlock.new("Can't lock #{type} recursively", fiber, fiber, lock, lock)
    end

    # :nodoc:
    def self.deadlock(fiber1, fiber2, lock1, lock2)
      f1 = to_name(fiber1)
      l1 = to_name(lock1, 1)

      f2 = to_name(fiber2)
      l2 = to_name(lock2, 2)

      message = "Fiber A (#{f1}) holds #{l1} and waits for #{l2}, while fiber B (#{f2}) holds #{l2} and waits for #{l1}"
      Deadlock.new(message, fiber1, fiber2, lock1, lock2)
    end

    private def self.to_name(fiber : Fiber)
      fiber.name || "0x#{fiber.object_id.to_s(16)}"
    end

    private def self.to_name(lock : Mutex | RWLock, i = nil)
      type =
        case lock
        in Mutex
          "mutex"
        in RWLock
          "rwlock"
        end
      "#{type}#{i} (0x#{lock.object_id.to_s(16)})"
    end
  end
end
