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
    @timespec = LibC::Timespec.new
    @armed = false
  end

  def arm(duration : Time::Span) : Nil
    @timespec.tv_sec = typeof(@timespec.tv_sec).new(duration.@seconds)
    @timespec.tv_nsec = typeof(@timespec.tv_nsec).new(duration.@nanoseconds)
    @armed = true
  end

  def disarm : Nil
    @armed = false
  end
end
