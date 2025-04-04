struct Crystal::EventLoop::IoUring::Event
  enum Type
    Async
    Sleep
    SelectTimeout
  end

  getter type : Type
  getter fiber : Fiber

  property! res : Int32
  # property! flags : UInt32

  getter! timeout : Time::Span

  def initialize(@type, @fiber)
    @armed = false
  end

  def timeout=(@timeout)
  end
end
