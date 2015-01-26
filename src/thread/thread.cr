require "./*"

class Thread(T, R)
  def self.new(&func : -> R)
    Thread(Nil, R).new(nil) { func.call }
  end

  def initialize(arg : T, &func : T -> R)
    @func = func
    @arg = arg
    ret = PThread.create(out @th, nil, ->(data) {
        (data as Thread(T, R)).start
      }, self as Void*)

    if ret != 0
      raise Errno.new("pthread_create")
    end
  end

  def join
    if PThread.join(@th, out _ret) != 0
      raise Errno.new("pthread_join")
    end

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
