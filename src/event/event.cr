require "./*"

# :nodoc:
module Event
  VERSION = String.new(LibEvent2.event_get_version)

  def self.callback(&block : Int32, LibEvent2::EventFlags, Void* ->)
    block
  end

  # :nodoc:
  struct Event
    def initialize(@event)
    end

    def add
      LibEvent2.event_add(@event, nil)
    end

    def add(timeout)
      t = to_timeval(timeout)
      LibEvent2.event_add(@event, pointerof(t))
    end

    def free
      LibEvent2.event_free(@event)
    end

    private def to_timeval(time : Int)
      t :: LibC::TimeVal
      t.tv_sec = typeof(t.tv_sec).cast(time)
      t.tv_usec = typeof(t.tv_usec).cast(0)
      t
    end

    private def to_timeval(time : Float)
      t :: LibC::TimeVal

      seconds = typeof(t.tv_sec).cast(time)
      useconds = typeof(t.tv_usec).cast((time - seconds) * 1e6)

      t.tv_sec = seconds
      t.tv_usec = useconds
      t
    end
  end

  # :nodoc:
  struct Base
    def initialize
      @base = LibEvent2.event_base_new
    end

    def reinit
      unless LibEvent2.event_reinit(@base) == 0
        raise "Error reinitializing libevent"
      end
    end

    def new_event(s : Int32, flags : LibEvent2::EventFlags, data, &callback : LibEvent2::Callback)
      event = LibEvent2.event_new(@base, s, flags, callback, data as Void*)
      Event.new(event)
    end

    def run_loop
      LibEvent2.event_base_loop(@base, LibEvent2::EventLoopFlags::None)
    end

    def run_once
      LibEvent2.event_base_loop(@base, LibEvent2::EventLoopFlags::Once)
    end

    def loop_break
      LibEvent2.event_base_loopbreak(@base)
    end

    def dns_base
      @dns_base ||= begin
        LibEvent2.evdns_base_new(@base, 1)
      end
    end
  end
end
