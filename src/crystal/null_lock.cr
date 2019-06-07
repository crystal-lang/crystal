# :nodoc:
struct Crystal::NullLock
  def sync
    yield
  end

  def unsync
    yield
  end
end
