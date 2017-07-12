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

    private def to_timeval(time : LibC::Timeval)
      time
    end

    private def to_timeval(time : Int)
      LibC::Timeval.new(tv_sec: time, tv_usec: 0)
    end

    private def to_timeval(time : Float)
      LibC::Timeval.new(tv_sec: time, tv_usec: (time - time.to_u64) * 1e6)
    end

    private def to_timeval(time : Time::Span)
      seconds, remainder_ticks = time.ticks.divmod(Time::Span::TicksPerSecond)
      LibC::Timeval.new(tv_sec: seconds, tv_usec: remainder_ticks / Time::Span::TicksPerMicrosecond)
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

    def new_event(fd : Int32, flags : LibEvent2::EventFlags, data, &callback : LibEvent2::Callback)
      event = LibEvent2.event_new(@base, fd, flags, callback, data.as(Void*))
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

    def new_dns_base(init = true)
      DnsBase.new LibEvent2.evdns_base_new(@base, init ? 1 : 0)
    end
  end

  struct DnsBase
    def initialize(@dns_base : LibEvent2::DnsBase)
    end

    def getaddrinfo(nodename, servname, hints, data, &callback : LibEvent2::DnsGetAddrinfoCallback)
      request = LibEvent2.evdns_getaddrinfo(@dns_base, nodename, servname, hints, callback, data.as(Void*))
      GetAddrInfoRequest.new request if request
    end

    struct GetAddrInfoRequest
      def initialize(@request : LibEvent2::DnsGetAddrinfoRequest)
      end

      def cancel
        LibEvent2.evdns_getaddrinfo_cancel(@request)
      end
    end
  end
end
