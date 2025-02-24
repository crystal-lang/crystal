# :nodoc:
class Crystal::AtomicSemaphore
  @m = Atomic(UInt32).new(0)

  def wait(&) : Nil
    m = @m.get
    while m == 0 || !@m.compare_and_set(m, m &- 1).last
      yield
      m = @m.get
    end
  end

  def signal : Nil
    @m.add(1)
  end
end
