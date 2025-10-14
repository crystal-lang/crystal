# :nodoc:
#
# Simpler, but thread unsafe, alternative to Crystal::FdLock that only
# serializes reads and writes and otherwise doesn't count references or waits
# for references before closing. This is mostly needed for the interpreter that
# happens to segfault with the thread safe alternative (see fd_lock_mt).
struct Crystal::FdLock
  CLOSED = 1_u8 << 0

  @m = 0_u8

  def reference(&)
    raise IO::Error.new("Closed") if closed?
    yield
  end

  def reset : Nil
    @m = 0_u8
  end

  def closed?
    (@m & CLOSED) == CLOSED
  end

  def try_close?(&)
    if closed?
      false
    else
      @m |= CLOSED

      yield
      true
    end
  end
end
