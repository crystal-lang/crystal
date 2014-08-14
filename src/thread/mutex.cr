class Mutex
  def initialize
    PThread.mutex_init(out @mutex, nil)
  end

  def lock
    PThread.mutex_lock(self)
  end

  def try_lock
    PThread.mutex_trylock(self)
  end

  def unlock
    PThread.mutex_unlock(self)
  end

  def synchronize
    lock
    yield self
  ensure
    unlock
  end

  def destroy
    PThread.mutex_destroy(self)
  end

  def to_unsafe
    pointerof(@mutex)
  end
end
