# :nodoc:
class Thread(T, R)
  # :nodoc:
  class Mutex
    @mutex : LibPThread::Mutex

    def initialize
      LibPThread.mutex_init(out @mutex, nil)
    end

    def lock
      LibPThread.mutex_lock(self)
    end

    def try_lock
      LibPThread.mutex_trylock(self)
    end

    def unlock
      LibPThread.mutex_unlock(self)
    end

    def synchronize
      lock
      yield self
    ensure
      unlock
    end

    def finalize
      LibPThread.mutex_destroy(self)
    end

    def to_unsafe
      pointerof(@mutex)
    end
  end
end
