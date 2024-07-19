{% skip_file unless flag?(:linux) || flag?(:solaris) %}

require "../epoll"
require "../timerfd"

struct Crystal::Epoll::Event
  enum Type
    IoRead
    IoWrite
    IoTimeout
    Sleep
    SelectTimeout
    System
  end

  getter fiber : Fiber
  getter type : Type
  getter fd : Int32

  property! timerfd : System::TimerFD
  getter? timed_out : Bool = false

  # an :io_read and :io_write event may have a linked :io_timeout
  # an :io_timeout event must be linked to an :io_read or :io_write event
  property! linked_event : Epoll::Event*

  include PointerLinkedList::Node

  # Allocates a system event into the HEAP. A system event doesn't have an
  # associated fiber.
  def self.system(fd : Int32) : self*
    event = Pointer(self).malloc(1)
    fiber = uninitialized Fiber
    event.value.initialize(fd, fiber, :system)
    event
  end

  def initialize(@fd : Int32, @fiber : Fiber, @type : Type)
  end

  def initialize(@timerfd : System::TimerFD, @fiber : Fiber, @type : Type)
    @fd = timerfd.fd
  end

  def timed_out! : Bool
    @timed_out = true
  end
end
