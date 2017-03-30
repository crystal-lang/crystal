require "./event/*"

# :nodoc:
module Event
  VERSION = String.new(LibEvent2.event_get_version)

  def self.callback(&block : Int32, LibEvent2::EventFlags, Void* ->)
    block
  end

  # :nodoc:
  struct Event
    def initialize(@event : LibEvent2::Event)
      @freed = false
    end

    def add
      LibEvent2.event_add(@event, nil)
    end

    def add(timeout)
      if timeout
        t = to_timeval(timeout)
        LibEvent2.event_add(@event, pointerof(t))
      else
        add
      end
    end

    def free
      LibEvent2.event_free(@event) unless @freed
      @freed = true
    end

    private def to_timeval(time : Int)
      t = uninitialized LibC::Timeval
      t.tv_sec = typeof(t.tv_sec).new(time)
      t.tv_usec = typeof(t.tv_usec).new(0)
      t
    end

    private def to_timeval(time : Float)
      t = uninitialized LibC::Timeval

      seconds = typeof(t.tv_sec).new(time)
      useconds = typeof(t.tv_usec).new((time - seconds) * 1e6)

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
      event = LibEvent2.event_new(@base, s, flags, callback, data.as(Void*))
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

    def to_unsafe
      @base
    end
  end

  # :nodoc:
  class DnsBase
    def initialize(base : Base)
      @dns_base = LibEvent2.evdns_base_new(base, 1)
    end

    def finalize
      LibEvent2.evdns_base_free(@dns_base)
    end

    def getaddrinfo(domain, service, hints, timeout = nil)
      addrinfo = error = nil

      request = LibEvent2.evdns_getaddrinfo(domain, service, hints, ->(result, addr, data) {
        if result == 0
          addrinfo = addr
        else
          error = errcode
        end
        Box(Fiber).unbox(data).resume
      }, Box.box(Fiber.current))

      if request
        # TODO: consider configuring DNS timeout globally:
        # (evdns_base_set_option("timeout", "5"))
        if timeout
          spawn do
            sleep timeout
            LibEvent2.evdns_getaddrinfo_cancel(request)
          end
        end

        Fiber.yield
      end

      if addrinfo
        yield addrinfo
      elsif error == LibEvent2::EVUTIL_EAI_CANCEL
        raise IO::Timeout.new("Failed to resolve #{domain} in #{timeout} seconds")
      else
        raise Socket::Error.new("evdns_getaddrinfo: #{String.new(LibEvent2.evutil_gai_strerror(error))}")
      end

      # TODO
    ensure
      LibEvent2.evutil_freeaddrinfo(addrinfo) if addrinfo
    end
  end
end
