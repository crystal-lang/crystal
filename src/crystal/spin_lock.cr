module Crystal
  # :nodoc:
  #
  # Spin lock that prevents threads from executing a critical section at the
  # same time. Since it blocks a thread from progressing, this should only be
  # used for fast thread synchronisation primitives.
  #
  # Uses a constant time fixed spin. See [Empirical Studies of Competitive
  # Spinning for A Shared-Memory
  # Multiprocessor](https://www.researchgate.net/publication/234794598_Empirical_studies_of_competitve_spinning_for_a_shared-memory_multiprocessor)
  # paper (1991) by Anna R. Karlin, Kai Li, Mark S. Manasse and Susan Owicki for
  # details, or alternative solutions that may help reduce contention.
  struct SpinLock
    def initialize
      @flag = Atomic::Flag.new
    end

    # Tries to acquire the lock or blocks the current operating system thread
    # until the lock is acquired.
    def lock : Nil
      # fast path: always succeeds with a single thread:
      until try_lock
        # fixed busy loop, avoids a thread context switch which improves
        # performance with many parallel threads:
        99.times do |i|
          return if try_lock
        end

        # give up, let the operating system resume another thread:
        Thread.yield
      end
    end

    # Tries to acquire the lock. Returns immediately with `true` if the lock was
    # acquired and `false` otherwise.
    def try_lock : Bool
      @flag.test_and_set
    end

    # Immediately unlocks the lock, assuming the current thread holds the lock
    # (be careful).
    def unlock : Nil
      @flag.clear
    end
  end
end
