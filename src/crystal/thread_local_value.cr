# :nodoc:
class Crystal::ThreadLocalValue(T)
  @values = Hash(Thread, T).new

  def get(&block : -> T)
    th = Thread.current
    @values.fetch(th) do
      @values[th] = yield
    end
  end

  def get?
    @values[Thread.current]?
  end

  def set(value : T)
    @values[Thread.current] = value
  end

  def each
    @values.each_value { |t| yield t }
  end

  def clear
    @values.clear
  end
end
