# :nodoc:
struct Crystal::ThreadLocalValue(T)
  @values = Hash(Thread, T).new
  @mutex = Crystal::SpinLock.new

  def get(&block : -> T)
    th = Thread.current
    @mutex.sync do
      @values.fetch(th) do
        @values[th] = yield
      end
    end
  end

  def get?
    @mutex.sync do
      @values[Thread.current]?
    end
  end

  def set(value : T)
    @mutex.sync do
      @values[Thread.current] = value
    end
  end

  def consume_each(&)
    @mutex.sync do
      @values.each_value { |t| yield t }
      @values.clear
    end
  end
end
