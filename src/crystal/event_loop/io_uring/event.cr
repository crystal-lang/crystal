require "crystal/pointer_pairing_heap"

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

  property! wake_at : Time::Span?

  # The event can be added to the `Timers` list.
  include PointerPairingHeap::Node

  # When using SQPOLL (or when IORING_FEAT_SUBMIT_STABLE is missing) the pointer
  # to the timespec struct must be reachable until the SQE has been successfully
  # submitted. We thus put the timespec on Event that is guaranteed to stay
  # alive until we receive the CQE (so we're fine).
  @timespec = uninitialized LibC::Timespec

  def initialize(@type, @fiber)
    @armed = false
  end

  def timeout=(timeout : Time::Span?)
    if timeout
      @timespec.tv_sec = typeof(@timespec.tv_sec).new(timeout.@seconds)
      @timespec.tv_nsec = typeof(@timespec.tv_nsec).new(timeout.@nanoseconds)
    end
    timeout
  end

  protected def timespec : Pointer(LibC::Timespec)
    pointerof(@timespec)
  end

  def heap_compare(other : Pointer(self)) : Bool
    wake_at < other.value.wake_at
  end
end
