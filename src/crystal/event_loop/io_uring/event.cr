struct Crystal::EventLoop::IoUring::Event
  enum Type
    Async
    Sleep
    SelectTimeout
  end

  getter type : Type
  getter fiber : Fiber
  property! cqe_res : Int32
  # property! cqe_flags : UInt32

  def initialize(@type, @fiber)
  end
end
