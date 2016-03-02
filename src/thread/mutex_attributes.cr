# :nodoc:
class Thread::MutexAttributes
  def initialize type
    t = LibPThread::MutexAttrType.parse(type.to_s)

    if LibPThread.mutexattr_init(out @attr) != 0
      raise Errno.new("pthread_mutexattr_init")
    end

    if LibPThread.mutexattr_settype(self, t) != 0
      raise Errno.new("pthread_mutexattr_settype")
    end
  end

  def finalize
    if LibPThread.mutexattr_destroy(self) != 0
      raise Errno.new("pthread_mutexattr_destroy")
    end
  end

  def to_unsafe
    pointerof(@attr)
  end
end
