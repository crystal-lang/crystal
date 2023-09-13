abstract class Crystal::EventLoop
  # Creates an event loop instance
  # def self.create : Crystal::EventLoop

  # Runs the event loop.
  abstract def run_once : Nil

  # Create a new resume event for a fiber.
  abstract def create_resume_event(fiber : Fiber) : Event

  # Creates a timeout_event.
  abstract def create_timeout_event(fiber : Fiber) : Event

  module Event
    # Frees the event.
    abstract def free : Nil

    # Adds a new timeout to this event.
    abstract def add(timeout : Time::Span?) : Nil
  end
end

{% if flag?(:wasi) %}
  require "./wasi/event_loop"
{% elsif flag?(:unix) %}
  require "./unix/event_loop_libevent"
{% elsif flag?(:win32) %}
  require "./win32/event_loop_iocp"
{% else %}
  {% raise "Event loop not supported" %}
{% end %}
