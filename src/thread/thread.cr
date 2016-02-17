require "./*"

# :nodoc:
class Thread(T, R)
  # Don't use this class, it is used internally by the event scheduler.
  # Use spawn and channels instead.

  def self.new(&func : -> R)
    Thread(Nil, R).new(nil) { func.call }
  end

  def initialize(arg : T, &func : T -> R)
    @func = func
    @arg = arg
    @detached = false
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

    # TODO: We need to cast ret to R, otherwise it'll be nilable
    # and we don't want that. But `@ret as R` gives
    # `can't cast Nil to NoReturn` in the case when the Thread's body is
    # NoReturn. The following trick works, but we should find another
    # way to do it.
    ret = @ret
    if ret.is_a?(R) # Always true
      ret
    else
      exit # unreachable, really
    end
  end

  protected def start
    begin
      @ret = @func.call(@arg)
    rescue ex
      @exception = ex
    end
  end
end
