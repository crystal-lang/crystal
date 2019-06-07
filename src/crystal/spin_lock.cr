# :nodoc:
class Crystal::SpinLock
  @m = Atomic(Int32).new(0)

  def lock
    until @m.compare_and_set(0, 1).last
    end
  end

  def unlock
    until @m.compare_and_set(1, 0).last
    end
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
