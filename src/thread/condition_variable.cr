# :nodoc:
class Thread(T, R)
  # :nodoc:
  class ConditionVariable
    @cond : LibPThread::Cond

    def initialize
      if LibPThread.cond_init(out @cond, nil) != 0
        raise Errno.new("pthread_cond_init")
      end
    end

    def signal
      if LibPThread.cond_signal(self) != 0
        raise Errno.new("pthread_cond_signal")
      end
    end

    def broadcast
      if LibPThread.cond_broadcast(self) != 0
        raise Errno.new("pthread_cond_broadcast")
      end
    end

    def wait(mutex : Thread::Mutex)
      if LibPThread.cond_wait(self, mutex) != 0
        raise Errno.new("pthread_cond_wait")
      end
    end

    def finalize
      if LibPThread.cond_destroy(self) != 0
        raise Errno.new("pthread_cond_broadcast")
      end
    end

    def to_unsafe
      pointerof(@cond)
    end
  end
end
