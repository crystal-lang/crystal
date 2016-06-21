require "c/pthread"

# :nodoc:
class Thread
  # :nodoc:
  class Mutex
    def initialize
      if LibC.pthread_mutex_init(out @mutex, nil) != 0
        raise Errno.new("pthread_mutex_init")
      end
    end

    def lock
      if LibC.pthread_mutex_lock(self) != 0
        raise Errno.new("pthread_mutex_lock")
      end
    end

    def try_lock
      if LibC.pthread_mutex_trylock(self) != 0
        raise Errno.new("pthread_mutex_trylock")
      end
    end

    def unlock
      if LibC.pthread_mutex_unlock(self) != 0
        raise Errno.new("pthread_mutex_unlock")
      end
    end

    def synchronize
      lock
      yield self
    ensure
      unlock
    end

    def finalize
      if LibC.pthread_mutex_destroy(self) != 0
        raise Errno.new("pthread_mutex_destroy")
      end
    end

    def to_unsafe
      pointerof(@mutex)
    end
  end
end
