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

    def add(timeout : LibC::Timeval? = nil)
      if timeout
        timeout_copy = timeout
        LibEvent2.event_add(@event, pointerof(timeout_copy))
      else
        LibEvent2.event_add(@event, nil)
      end
    end

    def add(timeout : Time::Span)
      add LibC::Timeval.new(
        tv_sec: timeout.total_seconds.to_i,
        tv_usec: timeout.nanoseconds / 1_000
      )
    end

    def free
      LibEvent2.event_free(@event) unless @freed
      @freed = true
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
