require "./event_loop_io_uring"
require "./event_loop_libevent"

class Crystal::EventLoop
  def self.create : Crystal::EventLoop
    {% if flag?(:linux) && flag?(:force_iouring) %}
      return IoUringEventLoop.new
    {% else %}
      {% if flag?(:linux) && flag?(:preview_iouring) %}
        if ENV["CRYSTAL_EVENTLOOP"]? == "io_uring" || Crystal::System::IoUring.available?
          return IoUringEventLoop.new
        end
      {% end %}

      return LibEventEventLoop.new
    {% end %}
  end
end
