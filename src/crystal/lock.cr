require "sync/mu"

module Crystal
  # :nodoc:
  #
  # Always checked alternative to Sync::Mutex and Sync::RWLock in a single and
  # significantly smaller type (no crystal type id, no lock type, no reentrancy
  # counter).
  struct Lock
    @mu = Sync::MU.new
    @locked_by : Fiber?

    def lock(&)
      unless @mu.try_lock?
        raise Sync::Error::Deadlock.new if deadlock?
        @mu.lock_slow
      end

      begin
        @locked_by = Fiber.current
        yield
      ensure
        @locked_by = nil
        @mu.unlock
      end
    end

    def rlock(&)
      @mu.rlock
      begin
        yield
      ensure
        @mu.runlock
      end
    end

    private def deadlock?
      @locked_by == Fiber.current
    end
  end
end
