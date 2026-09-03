# :nodoc:
struct Crystal::RWLock
  private UNLOCKED = 0
  private LOCKED   = 1

  @writer = Atomic(Int32).new(UNLOCKED)
  @readers = Atomic(Int32).new(0)

  def read_lock : Nil
    loop do
      while @writer.get(:relaxed) != UNLOCKED
        Intrinsics.pause
      end

      @readers.add(1, :acquire)

      if @writer.get(:acquire) == UNLOCKED
        return
      end

      @readers.sub(1, :release)
    end
  end

  def read_unlock : Nil
    @readers.sub(1, :release)
  end

  def write_lock : Nil
    while @writer.swap(LOCKED, :acquire) != UNLOCKED
      Intrinsics.pause
    end

    while @readers.get(:acquire) != 0
      Intrinsics.pause
    end
  end

  def write_unlock : Nil
    @writer.set(UNLOCKED, :release)
  end
end
