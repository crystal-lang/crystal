# :nodoc:
module Crystal::EventLoop::Lock
  @lock = Atomic(Bool).new(false)

  def lock?(&) : Bool
    if @lock.swap(true, :acquire) == false
      begin
        yield
      ensure
        @lock.set(false, :release)
      end
      true
    else
      false
    end
  end

  def interrupt? : Bool
    if @lock.get(:relaxed)
      interrupt
      true
    else
      false
    end
  end
end
