require "c/pthread"

# :nodoc:
class Thread
  # :nodoc:
  class ConditionVariable
    def initialize
      ret = LibC.pthread_cond_init(out @cond, nil)
      raise Errno.new("pthread_cond_init", ret) unless ret == 0
    end

    def signal
      ret = LibC.pthread_cond_signal(self)
      raise Errno.new("pthread_cond_signal", ret) unless ret == 0
    end

    def broadcast
      ret = LibC.pthread_cond_broadcast(self)
      raise Errno.new("pthread_cond_broadcast", ret) unless ret == 0
    end

    def wait(mutex : Thread::Mutex)
      ret = LibC.pthread_cond_wait(self, mutex)
      raise Errno.new("pthread_cond_wait", ret) unless ret == 0
    end

    def finalize
      ret = LibC.pthread_cond_destroy(self)
      raise Errno.new("pthread_cond_broadcast", ret) unless ret == 0
    end

    def to_unsafe
      pointerof(@cond)
    end
  end
end
