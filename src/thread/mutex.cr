class Mutex
  # Valid Types [:default, :normal, :recursive, :errorcheck]
  #
  # It is advised that an application should not use a PTHREAD_MUTEX_RECURSIVE
  # mutex with condition variables because the implicit unlock performed for a
  # pthread_cond_timedwait() or pthread_cond_wait() may not actually release
  # the mutex (if it had been locked multiple times). If this happens, no other
  # thread can satisfy the condition of the predicate.
  def initialize type = :default
    attr = Thread::MutexAttributes.new(type)

    if LibPThread.mutex_init(out @mutex, attr) != 0
      raise Errno.new("pthread_mutex_init")
    end
  end

  def lock
    if LibPThread.mutex_lock(self) != 0
      raise Errno.new("pthread_mutex_lock")
    end
    nil
  end

  def try_lock
    if (ret = LibPThread.mutex_trylock(self)) != 0
      return false if ret == Errno::EBUSY
      LibC.errno = ret
      raise Errno.new("pthread_mutex_trylock #{LibC.errno}")
    end
    true
  end

  def unlock
    if LibPThread.mutex_unlock(self) != 0
      raise Errno.new("pthread_mutex_lock")
    end
    nil
  end

  def synchronize
    lock
    yield self
  ensure
    unlock
  end

  def finalize
    if LibPThread.mutex_destroy(self) != 0
      raise Errno.new("pthread_mutex_lock")
    end
  end

  def to_unsafe
    pointerof(@mutex)
  end
end
