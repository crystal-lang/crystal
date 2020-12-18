# :nodoc:
class Crystal::SpinLock
  {% if flag?(:preview_mt) %}
    @m = Atomic(Int32).new(0)
  {% end %}

  def lock
    {% if flag?(:preview_mt) %}
      while @m.swap(1) == 1
        while @m.get == 1
          Intrinsics.pause
        end
      end
    {% end %}
  end

  def unlock
    {% if flag?(:preview_mt) %}
      @m.lazy_set(0)
    {% end %}
  end

  def sync
    lock
    begin
      yield
    ensure
      unlock
    end
  end

  def unsync
    unlock
    begin
      yield
    ensure
      lock
    end
  end
end
