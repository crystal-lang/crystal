require "./*"

module Event
  VERSION = String.new(LibEvent2.event_get_version)

  def self.callback(&block : Int32, LibEvent2::EventFlags, Void* ->)
    block
  end

  struct Event::Base
    def initialize
      @base = LibEvent2.event_base_new
    end

    def add_signal_event(signal, callback, data = nil)
      event = LibEvent2.event_new(@base, signal, LibEvent2::EventFlags::Signal | LibEvent2::EventFlags::Persist, callback, data)
      LibEvent2.event_add(event, nil)
    end

    def add_timer_event(time, callback, data = nil)
      event = LibEvent2.event_new(@base, -1, LibEvent2::EventFlags::None, callback, data)
      t = to_timeval(time)
      LibEvent2.event_add(event, pointerof(t))
    end

    def add_interval_event(time, callback, data = nil)
      event = LibEvent2.event_new(@base, -1, LibEvent2::EventFlags::Persist, callback, data)
      t = to_timeval(time)
      LibEvent2.event_add(event, pointerof(t))
    end

    def add_fd_read_event(fd, callback, data = nil)
      event = LibEvent2.event_new(@base, fd, LibEvent2::EventFlags::Read, callback, data)
      LibEvent2.event_add(event, nil)
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

    def to_unsafe
      @base
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
end
