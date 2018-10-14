require "c/pthread"

# :nodoc:
class Thread
  # :nodoc:
  class Mutex
    def initialize
      attributes = uninitialized LibC::PthreadMutexattrT
      LibC.pthread_mutexattr_init(pointerof(attributes))
      LibC.pthread_mutexattr_settype(pointerof(attributes), LibC::PTHREAD_MUTEX_ERRORCHECK)

      ret = LibC.pthread_mutex_init(out @mutex, pointerof(attributes))
      raise Errno.new("pthread_mutex_init", ret) unless ret == 0

      LibC.pthread_mutexattr_destroy(pointerof(attributes))
    end

    def lock
      ret = LibC.pthread_mutex_lock(self)
      raise Errno.new("pthread_mutex_lock", ret) unless ret == 0
    end

    def try_lock
      case ret = LibC.pthread_mutex_trylock(self)
      when 0
        true
      when Errno::EBUSY
        false
      else
        raise Errno.new("pthread_mutex_trylock", ret)
      end
    end

    def unlock
      ret = LibC.pthread_mutex_unlock(self)
      raise Errno.new("pthread_mutex_unlock", ret) unless ret == 0
    end

    def synchronize
      lock
      yield self
    ensure
      unlock
    end

    def finalize
      ret = LibC.pthread_mutex_destroy(self)
      raise Errno.new("pthread_mutex_destroy", ret) unless ret == 0
    end

    def to_unsafe
      pointerof(@mutex)
    end
  end
end
