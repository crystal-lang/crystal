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
    # :nodoc:
    # TODO: consider using a struct & pass pointer
    class Response
      property result : Int32?
      property addrinfo : Pointer(LibEvent2::EvutilAddrinfo)?

      def initialize(@fiber : Fiber)
      end

      def resume
        @fiber.resume
      end

      def cancelled?
        @result == LibEvent2::EVUTIL_EAI_CANCEL
      end
    end

    def initialize(base : Base)
      @dns_base = LibEvent2.evdns_base_new(base, 1)
    end

    def finalize
      LibEvent2.evdns_base_free(@dns_base, 1)
    end

    def getaddrinfo(domain, service, hints, timeout = nil, &block)
      response = Response.new(Fiber.current)

      request = LibEvent2.evdns_getaddrinfo(@dns_base, domain, service, hints, ->(result, addrinfo, data) {
        r = Box(Response).unbox(data)
        r.result = result
        r.addrinfo = addrinfo
        r.resume
      }, Box.box(response))

      # evdns returns a request only if the request is pending, otherwise the
      # callback was already called.
      if request
        # TODO: consider configuring DNS timeout globally: evdns_base_set_option("timeout", "5")
        if timeout
          spawn do
            sleep timeout.not_nil!
            LibEvent2.evdns_getaddrinfo_cancel(request)
          end
        end

        sleep # until explicitly resumed
      end

      if addrinfo = response.addrinfo
        yield addrinfo
      elsif response.cancelled?
        raise IO::Timeout.new("Failed to resolve #{domain} in #{timeout} seconds")
      else
        error = response.result.not_nil!
        raise Socket::Error.new("evdns_getaddrinfo: #{error}")
      end
    ensure
      if addrinfo = response.try(&.addrinfo)
        LibEvent2.evutil_freeaddrinfo(addrinfo)
      end
    end
  end
end
