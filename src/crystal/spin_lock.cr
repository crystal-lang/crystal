# :nodoc:
class Crystal::SpinLock
  @m = Atomic(Int32).new(0)

  def lock
    while @m.swap(1) == 1
      while @m.get == 1
      end
    end
  end

  def unlock
    @m.lazy_set(0)
  end

  def sync
    begin
      lock
      yield
    ensure
      unlock
    end
  end

  def unsync
    begin
      unlock
      yield
    ensure
      lock
    end
  end
end
