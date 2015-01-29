class ConditionVariable
  def initialize
    LibPThread.cond_init(out @cond, nil)
  end

  def signal
    LibPThread.cond_signal(self)
  end

  def wait(mutex : Mutex)
    LibPThread.cond_wait(self, mutex)
  end

  def finalize
    LibPThread.cond_destroy(pointerof(@cond))
  end

  def to_unsafe
    pointerof(@cond)
  end
end
