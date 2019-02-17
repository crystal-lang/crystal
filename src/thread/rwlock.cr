require "c/pthread"

# :nodoc:
class Thread
  # :nodoc:
  class RWLock
    def initialize
      ret = LibC.pthread_rwlock_init(out @rwlock, nil)
      raise Errno.new("pthread_rwlock_init", ret) unless ret == 0
    end

    def lock_read
      ret = LibC.pthread_rwlock_rdlock(self)
      raise Errno.new("pthread_rwlock_rdlock", ret) unless ret == 0
    end

    def lock_write
      ret = LibC.pthread_rwlock_wrlock(self)
      raise Errno.new("pthread_rwlock_wrlock", ret) unless ret == 0
    end

    def try_lock_read : Bool
      case ret = LibC.pthread_rwlock_tryrdlock(self)
      when 0
        true
      when Errno::EBUSY
        false
      else
        raise Errno.new("pthread_rwlock_tryrdlock", ret)
      end
    end

    def try_lock_write
      case ret = LibC.pthread_rwlock_trywrlock(self)
      when 0
        true
      when Errno::EBUSY
        false
      else
        raise Errno.new("pthread_rwlock_trywrlock", ret)
      end
    end

    def unlock
      ret = LibC.pthread_rwlock_unlock(self)
      raise Errno.new("pthread_rwlock_unlock", ret) unless ret == 0
    end

    def synchronize_read
      lock_read
      begin
        yield
      ensure
        unlock
      end
    end

    def synchronize_write
      lock_write
      begin
        yield
      ensure
        unlock
      end
    end

    def finalize
      ret = LibC.pthread_rwlock_destroy(self)
      raise Errno.new("pthread_rwlock_destroy", ret) unless ret == 0
    end

    def to_unsafe
      pointerof(@rwlock)
    end
  end
end
