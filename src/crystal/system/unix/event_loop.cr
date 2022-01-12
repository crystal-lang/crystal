{% if flag?(:linux) && !flag?(:interpreted) && flag?(:force_iouring) %}
  require "./event_loop_io_uring"
{% elsif flag?(:linux) && !flag?(:interpreted) && flag?(:preview_iouring) %}
  require "./event_loop_libevent"
  require "./event_loop_io_uring"
{% else %}
  require "./event_loop_libevent"
{% end %}

class Crystal::EventLoop
  def self.create : Crystal::EventLoop
    {% if flag?(:linux) && !flag?(:interpreted) && flag?(:force_iouring) %}
      return IoUringEventLoop.new
    {% else %}
      {% if flag?(:linux) && !flag?(:interpreted) && flag?(:preview_iouring) %}
        if ENV["CRYSTAL_EVENTLOOP"]? == "io_uring" || Crystal::System::IoUring.available?
          return IoUringEventLoop.new
        end
      {% end %}

      return LibEventEventLoop.new
    {% end %}
  end
end
