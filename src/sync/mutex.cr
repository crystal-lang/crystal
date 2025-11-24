require "./mu"
require "./type"
require "./errors"

module Sync
  # A mutual exclusion lock to protect critical sections.
  #
  # A single fiber can acquire the lock at a time. No other fiber can acquire
  # the lock while a fiber holds it.
  #
  # This lock can for example be used to protect the access to some resources,
  # with the guarantee that only one section of code can ever read, write or
  # mutate said resources.
  class Mutex
    def initialize(@type : Type = :checked)
      @counter = 0
      @mu = MU.new
    end

    # Acquires the exclusive lock for the duration of the block. The lock will
    # be released automatically before returning, or if the block raises an
    # exception.
    def synchronize(& : -> U) : U forall U
      lock
      begin
        yield
      ensure
        unlock
      end
    end

    # Acquires the exclusive lock.
    def lock : Nil
      unless @mu.try_lock?
        unless @type.unchecked?
          if owns_lock?
            raise Error::Deadlock.new unless @type.reentrant?
            @counter += 1
            return
          end
        end
        @mu.lock_slow
      end

      unless @type.unchecked?
        @locked_by = Fiber.current
        @counter = 1 if @type.reentrant?
      end
    end

    # Releases the exclusive lock.
    def unlock : Nil
      unless @type.unchecked?
        unless owns_lock?
          message =
            if @locked_by
              "Can't unlock Sync::Mutex locked by another fiber"
            else
              "Can't unlock Sync::Mutex that isn't locked"
            end
          raise Error.new(message)
        end
        if @type.reentrant?
          return unless (@counter -= 1) == 0
        end
        @locked_by = nil
      end
      @mu.unlock
    end

    protected def owns_lock? : Bool
      @locked_by == Fiber.current
    end

    # :nodoc:
    def dup
      {% raise "Can't dup {{@type}}" %}
    end
  end
end
