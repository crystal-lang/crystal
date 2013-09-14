lib PThread
  type Thread : Void*
  fun create = pthread_create(thread : Thread*, attr : Void*, start : Void* ->, arg : Void*)
  fun exit = pthread_exit(value : Void*)
  fun join = pthread_join(thread : Thread, value : Void**) : Int32
end

class Thread(T, R)
  def self.new(arg : T, &block : T -> R)
    Thread(T, R).new(arg, block)
  end

  def self.new(&block : Nil -> R)
    Thread(Nil, R).new(nil, block)
  end

  def initialize(arg : T, func)
    @func = func
    @arg = arg
    PThread.create(out @th, nil, ->start(Void*), nil)
  end

  def start(x)
    ret = Pointer(R).malloc(1)
    ret.value = @func.call(@arg)
    PThread.exit(ret.as(Void))
  end

  def join
    PThread.join(@th, out ret)
    ret.as(R).value
  end
end
