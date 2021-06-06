{% if flag?(:linux) && (flag?(:preview_iouring) || flag?(:force_iouring)) %}
  require "./io_uring"

  {% if flag?(:preview_mt) %}
    class Thread
      # :nodoc:
      getter(io_uring) { Crystal::System::IoUring.new(128) }
    end

    module Crystal::System
      def self.io_uring
        Thread.current.io_uring
      end
    end
  {% else %}
    module Crystal::System
      class_getter(io_uring) { Crystal::System::IoUring.new(128) }

      def self.reset_io_uring
        @@io_uring = nil
      end
    end
  {% end %}
{% end %}

{% unless flag?(:linux) && flag?(:force_iouring) %}
  class Thread
    # :nodoc:
    getter(event_base) { Crystal::LibEvent::Base.new }
  end
{% end %}

module Crystal::System
  struct IoPerformer
    property! event : Crystal::Event

    {% if flag?(:linux) && flag?(:preview_iouring) %}
      @@use_io_uring = begin
        case ENV["CRYSTAL_EVENTLOOP"]?
        when "io_uring"
          true
        when "libevent"
          false
        else
          Crystal::System::IoUring.available?
        end
      end
    {% end %}

    def io_uring
      {% if flag?(:linux) && (flag?(:preview_iouring) || flag?(:force_iouring)) %}
        {% if flag?(:force_iouring) %}
          @event ||= yield
        {% else %}
          if @@use_io_uring
            @event ||= yield
          end
        {% end %}
      {% end %}
    end

    def lib_event
      {% unless flag?(:linux) && flag?(:force_iouring) %}
        @event ||= yield Thread.current.event_base
      {% end %}
    end
  end

  def self.perform_io : Nil
    performer = IoPerformer.new
    with performer yield
  end

  def self.perform_io_event
    performer = IoPerformer.new
    with performer yield
    performer.event
  end
end
