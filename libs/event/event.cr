require "./*"

module Event
  VERSION = String.new(LibEvent2.event_get_version)

  def self.callback(&block : Int32, UInt16, Void* ->)
    block
  end

  struct Event::Base
    def initialize
      @base = LibEvent2.event_base_new
    end

    def add_signal_event(signal, callback, data = nil)
      event = LibEvent2.event_new(@base, signal, LibEvent2::SIGNAL | LibEvent2::PERSIST, callback, data)
      LibEvent2.event_add(event, nil)
    end

    def add_timer_event(time, callback, data = nil)
      event = LibEvent2.event_new(@base, -1, 0_u16, callback, data)
      t :: C::TimeVal
      t.tv_sec = time.to_i64
      t.tv_usec = 0
      LibEvent2.event_add(event, pointerof(t))
    end

    def add_interval_event(time, callback, data = nil)
      event = LibEvent2.event_new(@base, -1, LibEvent2::PERSIST, callback, data)
      t :: C::TimeVal
      t.tv_sec = time.to_i64
      t.tv_usec = 0
      LibEvent2.event_add(event, pointerof(t))
    end

    def add_fd_read_event(fd, callback, data = nil)
      event = LibEvent2.event_new(@base, fd, LibEvent2::READ, callback, data)
      LibEvent2.event_add(event, nil)
    end

    def run_loop
      LibEvent2.event_base_loop(@base, 0)
    end

    def loop_break
      LibEvent2.event_base_loopbreak(@base)
    end
  end
end
