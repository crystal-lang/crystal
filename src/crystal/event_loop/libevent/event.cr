require "./lib_event2"

{% if flag?(:preview_mt) %}
  LibEvent2.evthread_use_pthreads
{% end %}

# :nodoc:
class Crystal::EventLoop::LibEvent < Crystal::EventLoop
  struct Event
    include Crystal::EventLoop::Event

    VERSION = String.new(LibEvent2.event_get_version)

    def self.callback(&block : Int32, LibEvent2::EventFlags, Void* ->)
      block
    end

    def initialize(@event : LibEvent2::Event)
      @freed = false
    end

    def add(timeout : Time::Span) : Nil
      timeval = LibC::Timeval.new(
        tv_sec: LibC::TimeT.new(timeout.total_seconds),
        tv_usec: timeout.nanoseconds // 1_000
      )
      LibEvent2.event_add(@event, pointerof(timeval))
    end

    def add(timeout : Nil) : Nil
      LibEvent2.event_add(@event, nil)
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
        LibEvent::Event.new(event)
      end

      # NOTE: may return `true` even if no event has been triggered (e.g.
      #       nonblocking), but `false` means that nothing was processed.
      def loop(flags : LibEvent2::EventLoopFlags) : Bool
        LibEvent2.event_base_loop(@base, flags) == 0
      end

      def loop_break : Nil
        LibEvent2.event_base_loopbreak(@base)
      end

      def loop_exit : Nil
        LibEvent2.event_base_loopexit(@base, nil)
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
