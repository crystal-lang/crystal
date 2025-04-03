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

  getter? armed : Bool

  def initialize(@type, @fiber)
    @duration = Time::Span.zero
    @armed = false
  end

  def arm(@duration : Time::Span) : Nil
    @armed = true
  end

  def disarm : Nil
    @armed = false
  end
end
