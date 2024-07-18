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
    Interrupt
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

  def self.interrupt(fd : Int32) : self*
    event = Pointer(self).malloc(1)
    fiber = uninitialized Fiber
    event.value.initialize(fd, fiber, :interrupt)
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
