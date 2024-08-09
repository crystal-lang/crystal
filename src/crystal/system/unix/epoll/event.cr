{% skip_file unless flag?(:linux) || flag?(:solaris) %}

require "../epoll"
require "../timerfd"

struct Crystal::Epoll::Event
  enum Type
    IoRead
    IoWrite
    Sleep
    SelectTimeout
    System
  end

  getter fiber : Fiber
  getter type : Type
  getter fd : Int32

  property! time : Time::Span?
  getter? timed_out : Bool = false

  include PointerLinkedList::Node

  # Allocates a system event into the HEAP. A system event doesn't have an
  # associated fiber.
  def self.system(fd : Int32) : self*
    event = Pointer(self).malloc(1)
    fiber = uninitialized Fiber
    event.value.initialize(fd, fiber, :system)
    event
  end

  def initialize(@fd : Int32, @fiber : Fiber, @type : Type, timeout : Time::Span? = nil)
    @time = ::Time.monotonic + timeout if timeout
  end

  def timed_out! : Bool
    @timed_out = true
  end
end
