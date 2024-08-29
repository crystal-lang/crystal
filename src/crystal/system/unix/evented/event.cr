struct Crystal::Evented::Event
  enum Type
    IoRead
    IoWrite
    Sleep
    SelectTimeout
    System
  end

  getter! fiber : Fiber
  getter! gen_index : Int64?
  getter type : Type
  getter! wake_at : Time::Span
  getter? timed_out : Bool = false

  include PointerLinkedList::Node

  def initialize(@type, @fiber = nil, @gen_index = nil, timeout : Time::Span? = nil)
    @wake_at = Time.monotonic + timeout if timeout
  end

  def timed_out! : Bool
    @timed_out = true
  end

  def wake_at=(@wake_at)
  end
end
