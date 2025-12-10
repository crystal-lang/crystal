require "./mu"
require "./type"
require "./errors"
require "./lockable"

module Sync
  # A multiple readers and exclusive writer lock to protect critical sections.
  #
  # Multiple fibers can acquire the shared lock (read) to allow some critical
  # sections to run concurrently. However a single fiber can acquire the
  # exclusive lock at a time to protect a single critical section to ever run in
  # parallel. When the lock has been acquired in exclusive mode, no other fiber
  # can lock it, be it in shared or exclusive mode.
  #
  # For example, the shared mode can allow to read one or many resources, albeit
  # the resources must be safe to be accessed in such manner, while the
  # exclusive mode allows to safely replace or mutate the resources with the
  # guarantee that nothing else is accessing said resources.
  #
  # The implementation doesn't favor readers or writers in particular.
  #
  # NOTE: Consider `Shared(T)` to protect a value `T` with a `RWLock`.
  class RWLock
    include Lockable

    def initialize(@type : Type = :checked)
      @counter = 0
      @mu = MU.new
    end

    # Acquires the shared (read) lock for the duration of the block.
    #
    # Multiple fibers can acquire the shared (read) lock at the same time. The
    # block will never run concurrently to an exclusive (write) lock.
    def read(& : -> U) : U forall U
      lock_read
      begin
        yield
      ensure
        unlock_read
      end
    end

    # Tries to acquire the shared (read) lock without blocking. Returns true
    # when acquired, otherwise returns false immediately.
    def try_lock_read? : Bool
      @mu.try_rlock?
    end

    # Acquires the shared (read) lock.
    #
    # The shared lock is always reentrant, multiple fibers can lock it multiple
    # times each, and never checked. Blocks the calling fiber while the
    # exclusive (write) lock is held.
    def lock_read : Nil
      @mu.rlock
    end

    # Releases the shared (read) lock.
    #
    # Every fiber that locked must unlock to actually release the reader lock
    # (so a writer can lock). If a fiber locked multiple times (reentrant
    # behavior) then it must unlock that many times.
    def unlock_read : Nil
      @mu.runlock
    end

    # Acquires the exclusive (write) lock for the duration of the block.
    #
    # Only one fiber can acquire the exclusive (write) lock at the same time.
    # The block will never run concurrently to a shared (read) lock or another
    # exclusive (write) lock.
    def write(& : -> U) : U forall U
      lock_write
      begin
        yield
      ensure
        unlock_write
      end
    end

    # Tries to acquire the exclusive (write) lock without blocking. Returns true
    # when acquired, otherwise returns false immediately.
    def try_lock_write? : Bool
      @mu.try_lock?
    end

    # Acquires the exclusive (write) lock. Blocks the calling fiber while the
    # shared or exclusive (write) lock is held.
    def lock_write : Nil
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

    # Releases the exclusive (write) lock.
    def unlock_write : Nil
      unless @type.unchecked?
        unless owns_lock?
          message =
            if @locked_by
              "Can't unlock Sync::RWLock locked by another fiber"
            else
              "Can't unlock Sync::RWLock that isn't locked"
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

    protected def wait(cv : Pointer(CV)) : Nil
      counter = 1

      unless @type.unchecked?
        if @mu.held?
          raise Error.new("Can't unlock Sync::RWLock locked by another fiber") unless owns_lock?
          @locked_by = nil
          counter, @counter = @counter, 0 if @type.reentrant?
        elsif !@mu.rheld?
          raise Error.new("Can't unlock Sync::RWLock that isn't locked")
        end
      end

      cv.value.wait pointerof(@mu)

      unless @type.unchecked? || @mu.rheld?
        @locked_by = Fiber.current
        @counter = counter if @type.reentrant?
      end
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
