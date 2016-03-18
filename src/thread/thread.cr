require "./*"

# :nodoc:
class Thread(T, R)
  # Don't use this class, it is used internally by the event scheduler.
  # Use spawn and channels instead.

  def self.new(&func : -> R)
    Thread(Nil, R).new(nil) { func.call }
  end

  @func : T -> R
  @arg : T
  @detached : Bool
  @th : LibPThread::Thread
  @ret : R
  @exception : Exception?

  def initialize(arg : T, &func : T -> R)
    @func = func
    @arg = arg
    @detached = false
    @ret = uninitialized R
    ret = LibPThread.create(out @th, nil, ->(data) {
      (data as Thread(T, R)).start
    }, self as Void*)

    if ret != 0
      raise Errno.new("pthread_create")
    end
  end

  def finalize
    LibPThread.detach(@th) unless @detached
  end

  def join
    if LibPThread.join(@th, out _ret) != 0
      raise Errno.new("pthread_join")
    end
    @detached = true

    if exception = @exception
      raise exception
    end

    @ret
  end

  protected def start
    begin
      @ret = @func.call(@arg)
    rescue ex
      @exception = ex
    end
  end
end
