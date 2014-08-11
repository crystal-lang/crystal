class Mutex
  def initialize
    PThread.mutex_init(out @mutex, nil)
  end

  def lock
    PThread.mutex_lock(pointerof(@mutex))
  end

  def try_lock
    PThread.mutex_trylock(pointerof(@mutex))
  end

  def unlock
    PThread.mutex_unlock(pointerof(@mutex))
  end

  def synchronize
    lock
    yield self
  ensure
    unlock
  end

  def destroy
    PThread.mutex_destroy(pointerof(@mutex))
  end

  def mutex_ptr
    pointerof(@mutex)
  end
end
