module Crystal::EventLoop
  # Runs the event loop.
  # def self.resume : Nil

  # Reinitializes the event loop after a fork.
  # def self.after_fork : Nil

  # Create a new resume event for a fiber.
  # def self.create_resume_event(fiber : Fiber) : Crystal::Event

  # Creates a write event for a file descriptor.
  # def self.create_fd_write_event(io : IO::Evented, edge_triggered : Bool = false)

  # Creates a read event for a file descriptor.
  # def self.create_fd_read_event(io : IO::Evented, edge_triggered : Bool = false)
end

struct Crystal::Event
  # Frees the event.
  # def free : Nil

  # Adds a new timeout to this event.
  # def add(time_span : Time::Span?) : Nil
end

{% if flag?(:unix) %}
  require "./event/event_loop_libevent"
{% else %}
  {% raise "event_loop not supported" %}
{% end %}
