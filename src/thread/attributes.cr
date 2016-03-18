# :nodoc:
class Thread::Attributes
  def initialize
    if LibPThread.attr_init(out @attr) != 0
      raise Errno.new("pthread_attr_init")
    end
  end

  def stack
    if LibPThread.attr_getstack(self, out addr, out ssize) != 0
      raise Errno.new("pthread_attr_getstack")
    end
    {addr, ssize}
  end

  def stack= addrsize
    addr, ssize = addrsize
    if LibPThread.attr_setstack(self, addr, ssize) != 0
      raise Errno.new("pthread_attr_setstack")
    end
    addrsize
  end

  def to_unsafe
    pointerof(@attr)
  end

  def destroy
    if LibPThread.attr_destroy(self) != 0
      raise Errno.new("pthread_attr_destroy")
    end
  end
end
