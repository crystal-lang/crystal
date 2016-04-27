require "c/pthread"
require "./*"

# :nodoc:
class Thread(T, R)
  # Don't use this class, it is used internally by the event scheduler.
  # Use spawn and channels instead.

  def self.new(&func : -> R)
    Thread(Nil, R).new(nil) { func.call }
  end

  @th : LibC::PthreadT?
  @exception : Exception?

  def initialize(@arg : T, &@func : T -> R)
    @detached = false
    @ret = uninitialized R
    ret = LibGC.pthread_create(out th, nil, ->(data) {
      (data as Thread(T, R)).start
    }, self as Void*)
    @th = th

    if ret != 0
      raise Errno.new("pthread_create")
    end
  end

  def finalize
    LibGC.pthread_detach(@th.not_nil!) unless @detached
  end

  def join
    if LibGC.pthread_join(@th.not_nil!, out _ret) != 0
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
