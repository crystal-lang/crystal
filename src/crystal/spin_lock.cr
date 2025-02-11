# :nodoc:
struct Crystal::SpinLock
  private UNLOCKED = 0
  private LOCKED   = 1

  {% if flag?(:preview_mt) %}
    @m = Atomic(Int32).new(UNLOCKED)
  {% end %}

  def lock
    {% if flag?(:preview_mt) %}
      while @m.swap(LOCKED, :acquire) == LOCKED
        while @m.get(:relaxed) == LOCKED
          Intrinsics.pause
        end
      end
    {% end %}
  end

  def unlock
    {% if flag?(:preview_mt) %}
      @m.set(UNLOCKED, :release)
    {% end %}
  end

  def sync(&)
    lock
    begin
      yield
    ensure
      unlock
    end
  end

  def unsync(&)
    unlock
    begin
      yield
    ensure
      lock
    end
  end
end
