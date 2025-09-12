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

  getter? timeout : Time::Span?

  # When using SQPOLL (or when IORING_FEAT_SUBMIT_STABLE is missing) the pointer
  # to the timespec struct must be reachable until the SQE has been successfully
  # submitted.
  @timespec = uninitialized LibC::Timespec

  def initialize(@type, @fiber)
    @armed = false
  end

  def timeout=(timeout : Time::Span?)
    if timeout
      @timespec.tv_sec = typeof(@timespec.tv_sec).new(timeout.@seconds)
      @timespec.tv_nsec = typeof(@timespec.tv_nsec).new(timeout.@nanoseconds)
    end
    @timeout = timeout
  end

  protected def timespec : Pointer(LibC::Timespec)
    pointerof(@timespec)
  end
end
