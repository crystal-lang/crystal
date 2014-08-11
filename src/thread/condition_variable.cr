class ConditionVariable
  def initialize
    PThread.cond_init(out @cond, nil)
  end

  def signal
    PThread.cond_signal(pointerof(@cond))
  end

  def wait(mutex : Mutex)
    PThread.cond_wait(pointerof(@cond), mutex.mutex_ptr)
  end

  def finalize
    PThread.cond_destroy(pointerof(@cond))
  end
end
