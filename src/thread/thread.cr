require "./*"

class Thread(T, R)
  def self.new(&func : -> R)
    Thread(Nil, R).new(nil) { func.call }
  end

  def initialize(arg : T, &func : T -> R)
    @func = func
    @arg = arg
    PThread.create(out @th, nil, ->(data) {
        (data as Thread(T, R)).start
      }, self as Void*)
  end

  def join
    PThread.join(@th, out ret)

    if exception = @exception
      raise exception
    end

    (ret as R*).value
  end

  protected def start
    begin
      ret = Pointer(R).malloc_one(@func.call(@arg))
      PThread.exit(ret as Void*)
    rescue ex
      @exception = ex
    end
  end
end
