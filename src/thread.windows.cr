
# :nodoc:
class Thread
  # Don't use this class, it is used internally by the event scheduler.
  # Use spawn and channels instead.

  @th : LibWindows::Handle?
  @exception : Exception?

  property current_fiber

  def initialize(&@func : ->)
    @current_fiber = uninitialized Fiber
    @@threads << self
    @th = LibGC.create_thread(nil, 0, ->(data) {
      (data.as(Thread)).start
      return 0u32
    }, self.as(Void*), 0, nil)

    if @th.not_nil!.null?
      raise WinError.new "CreateThread"
    end
  end

  def initialize
    @current_fiber = uninitialized Fiber
    @func = ->{}
    @@threads << self
    proc = LibWindows.get_current_process
    th = LibWindows.get_current_thread
    LibWindows.duplicate_handle(proc, th, proc, pointerof(th), 0, false, 0)
    @th = th
  end

  def finalize
    LibWindows.close_handle(@th.not_nil!)
  end

  def join
    if LibWindows.wait_for_single_object(@th.not_nil!, LibWindows::INFINITY) != LibWindows::WAIT_OBJECT_0
      raise WinError.new "WaitForSingleObject"
    end

    if exception = @exception
      raise exception
    end
  end

  # All threads, so the GC can see them (GC doesn't scan thread locals)
  # and we can find the current thread on platforms that don't support
  # thread local storage (eg: OpenBSD)
  @@threads = Set(Thread).new

  @[ThreadLocal]
  @@current = new

  def self.current
    @@current
  end

  protected def start
    @@current = self
    begin
      @func.call
    rescue ex
      @exception = ex
    ensure
      @@threads.delete(self)
    end
  end
end
