# :nodoc:
struct Crystal::NullLock
  def lock
  end

  def unlock
  end

  def sync
    yield
  end

  def unsync
    yield
  end
end
