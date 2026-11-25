module Sync
  # Raised when a sync check fails. For example when trying to unlock an
  # unlocked mutex. See `#message` for details.
  class Error < Exception
    # Raised when a lock would result in a deadlock. For example when trying to
    # re-lock a checked mutex.
    class Deadlock < Error
      getter fiber1 : Fiber?
      getter fiber2 : Fiber?

      getter lock1 : Lockable?
      getter lock2 : Lockable?

      def initialize(message : String, @fiber1 = nil, @fiber2 = nil, @lock1 = nil, @lock2 = nil)
        super(message)
      end

      # :nodoc:
      def self.new(fiber : Fiber, lock : Lockable)
        new("Can't lock #{lock.class.name} recursively", fiber, fiber, lock, lock)
      end

      # :nodoc:
      def self.new(fiber1 : Fiber, fiber2 : Fiber, lock1 : Lockable, lock2 : Lockable)
        f1 = to_name(fiber1)
        l1 = to_name(lock1, 1)

        f2 = to_name(fiber2)
        l2 = to_name(lock2, 2)

        message = "Fiber #{f1} holds #{l1} and waits for #{l2}, while fiber #{f2} holds #{l2} and waits for #{l1}"
        new(message, fiber1, fiber2, lock1, lock2)
      end

      private def self.to_name(fiber : Fiber)
        String.build do |io|
          if name = fiber.name
            io << name << " "
          end
          io << "(0x"
          fiber.object_id.to_s(io, 16)
          io << ")"
        end
      end

      private def self.to_name(lock, i = nil)
        String.build do |io|
          lock.class.name.downcase(io)
          io << i << " (0x"
          lock.object_id.to_s(io, 16)
          io << ")"
        end
      end
    end
  end
end
