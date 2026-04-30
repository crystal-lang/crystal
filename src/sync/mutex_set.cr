module Sync
  # The `MutexSet` is a collection of `Sync::Mutex`es that must all be locked in
  # a deterministic order.
  struct MutexSet
    @mutexes : Array(Sync::Mutex)

    def initialize(mutexes : Enumerable(Sync::Mutex))
      @mutexes = mutexes.sort_by(&.lock_id).uniq!
    end

    # Locks all mutexes in this `MutexSet` in a deterministic order for the duration of the block.
    def synchronize(&)
      lock
      yield
    ensure
      unlock
    end

    # Locks all mutexes in this `MutexSet` in a deterministic order.
    def lock
      @mutexes.each(&.lock)
    end

    # Unlocks all mutexes in this `MutexSet` in a deterministic order.
    def unlock
      @mutexes.reverse_each(&.unlock)
    end
  end
end
