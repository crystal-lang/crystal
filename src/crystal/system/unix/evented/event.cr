struct Crystal::Evented::Event
  enum Type
    IoRead
    IoWrite
    Sleep
    SelectTimeout
    System
  end

  getter! fiber : Fiber
  getter type : Type
  getter fd : Int32
  property! wake_at : Time::Span
  getter? timed_out : Bool = false

  include PointerLinkedList::Node

  # Initializes a system event. A system event doesn't have an associated fiber.
  def self.system(fd : Int32) : self*
    new(fd, nil, :system)
  end

  def initialize(@type : Type, @fd : Int32, @fiber : Fiber? = nil, timeout : Time::Span? = nil)
    @wake_at = Time.monotonic + timeout if timeout
  end

  def timed_out! : Bool
    @timed_out = true
  end
end
