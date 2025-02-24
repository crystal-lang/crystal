# NOTE: this struct is only needed to be able to re-use `PointerPairingHeap`
# because EventLoop::Polling uses pointers. If `EventLoop::Polling::Event` was a
# reference, then `PairingHeap` wouldn't need pointers, and this struct could be
# merged into `Event`.
struct Crystal::EventLoop::IOCP::Timer
  enum Type
    Sleep
    SelectTimeout
  end

  getter type : Type

  # The `Fiber` that is waiting on the event and that the `EventLoop` shall
  # resume.
  getter fiber : Fiber

  # The absolute time, against the monotonic clock, at which a timed event shall
  # trigger. Nil for IO events without a timeout.
  getter! wake_at : Time::Span

  # True if an IO event has timed out (i.e. we're past `#wake_at`).
  getter? timed_out : Bool = false

  # The event can be added to the `Timers` list.
  include PointerPairingHeap::Node

  def initialize(@type : Type, @fiber)
  end

  def wake_at=(@wake_at)
  end

  def timed_out! : Bool
    @timed_out = true
  end

  def heap_compare(other : Pointer(self)) : Bool
    wake_at < other.value.wake_at
  end
end
