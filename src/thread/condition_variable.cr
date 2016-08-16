require "c/pthread"

# :nodoc:
class Thread
  # :nodoc:
  class ConditionVariable
    def initialize
      if LibC.pthread_cond_init(out @cond, nil) != 0
        raise Errno.new("pthread_cond_init")
      end
    end

    def signal
      if LibC.pthread_cond_signal(self) != 0
        raise Errno.new("pthread_cond_signal")
      end
    end

    def broadcast
      if LibC.pthread_cond_broadcast(self) != 0
        raise Errno.new("pthread_cond_broadcast")
      end
    end

    def wait(mutex : Thread::Mutex)
      if LibC.pthread_cond_wait(self, mutex) != 0
        raise Errno.new("pthread_cond_wait")
      end
    end

    def finalize
      if LibC.pthread_cond_destroy(self) != 0
        raise Errno.new("pthread_cond_broadcast")
      end
    end

    def to_unsafe
      pointerof(@cond)
    end
  end
end
