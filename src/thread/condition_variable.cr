class ConditionVariable
  def initialize
    PThread.cond_init(out @cond, nil)
  end

  def signal
    PThread.cond_signal(self)
  end

  def wait(mutex : Mutex)
    PThread.cond_wait(self, mutex)
  end

  def finalize
    PThread.cond_destroy(pointerof(@cond))
  end

  def to_unsafe
    pointerof(@cond)
  end
end
