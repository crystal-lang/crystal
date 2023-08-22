require "./lib_event2"

{% if flag?(:preview_mt) %}
  LibEvent2.evthread_use_pthreads
{% end %}

# :nodoc:
module Crystal::LibEvent
  struct Event
    include Crystal::EventLoop::Event

    VERSION = String.new(LibEvent2.event_get_version)

    def self.callback(&block : Int32, LibEvent2::EventFlags, Void* ->)
      block
    end

    def initialize(@event : LibEvent2::Event)
      @freed = false
    end

    def add(timeout : Time::Span?) : Nil
      if timeout
        timeval = LibC::Timeval.new(
          tv_sec: LibC::TimeT.new(timeout.total_seconds),
          tv_usec: timeout.nanoseconds // 1_000
        )
        LibEvent2.event_add(@event, pointerof(timeval))
      else
        LibEvent2.event_add(@event, nil)
      end
    end

    def free : Nil
      LibEvent2.event_free(@event) unless @freed
      @freed = true
    end

    def delete
      unless LibEvent2.event_del(@event) == 0
        raise "Error deleting event"
      end
    end

    # :nodoc:
    struct Base
      def initialize
        @base = LibEvent2.event_base_new
      end

      def reinit : Nil
        unless LibEvent2.event_reinit(@base) == 0
          raise "Error reinitializing libevent"
        end
      end

      def new_event(s : Int32, flags : LibEvent2::EventFlags, data, &callback : LibEvent2::Callback)
        event = LibEvent2.event_new(@base, s, flags, callback, data.as(Void*))
        Crystal::LibEvent::Event.new(event)
      end

      def run_loop : Nil
        LibEvent2.event_base_loop(@base, LibEvent2::EventLoopFlags::None)
      end

      def run_once : Nil
        LibEvent2.event_base_loop(@base, LibEvent2::EventLoopFlags::Once)
      end

      def loop_break : Nil
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
end
