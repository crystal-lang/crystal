require "./lib_event2"

# :nodoc:
class Crystal::Event
  VERSION = String.new(LibEvent2.event_get_version)

  {% if flag?(:abi64) %}
    # align to 8 bytes:
    SIZE_SELF = (instance_sizeof(Crystal::Event) + 7) & (~7)
    SIZE = SIZE_SELF + ((LibEvent2.event_get_struct_event_size + 7) & (~7))
  {% else %}
    # align to 4 bytes:
    SIZE_SELF = (instance_sizeof(Crystal::Event) + 3) & (~3)
    SIZE = SIZE_SELF + ((LibEvent2.event_get_struct_event_size + 3) & (~3))
  {% end %}

  property? timed_out : Bool

  # Avoids a double memory allocation while retaining compatibility with
  # various libevent versions that may use different sizes for the opaque
  # `struct event`.
  def self.allocate_once : self
    event = GC.malloc(SIZE).as(Crystal::Event)
    event.initialize
    event
  end

  # :nodoc:
  def initialize
    @timed_out = false
    Crystal::EventLoop.event_base.event_assign(self, -1, LibEvent2::EventFlags.new(0), nil) { }
  end

  def finalize
    LibEvent2.event_del(self)
  end

  def add(timeout : LibC::Timeval? = nil)
    @timed_out = false

    {% if flag?(:mt) %}
      @canceled.clear
    {% end %}

    if timeout
      timeout_copy = timeout
      LibEvent2.event_add(self, pointerof(timeout_copy))
    else
      LibEvent2.event_add(self, nil)
    end
  end

  def add(timeout : Time::Span)
    add LibC::Timeval.new(
      tv_sec: LibC::TimeT.new(timeout.total_seconds),
      tv_usec: timeout.nanoseconds / 1_000
    )
  end

  def del
    LibEvent2.event_del(self)
  end

  {% if flag?(:mt) %}
    @canceled = Atomic::Flag.new

    def cancel(delete = true)
      success = @canceled.test_and_set
      del if delete && success
      success
    end
  {% end %}

  def to_unsafe
    (self.as(Void*) + SIZE_SELF).as(LibEvent2::Event)
  end

  # :nodoc:
  struct Base
    def initialize
      {% if flag?(:mt) %}
        {% if flag?(:win32) %}
          LibEvent2.evthread_use_windows_threads
        {% else %}
          LibEvent2.evthread_use_pthreads
        {% end %}
      {% end %}
      @base = LibEvent2.event_base_new
    end

    def reinit
      unless LibEvent2.event_reinit(@base) == 0
        raise "Error reinitializing libevent"
      end
    end

    def event_assign(event : Event, fd : Int32, flags : LibEvent2::EventFlags, data, &callback : LibEvent2::Callback)
      LibEvent2.event_assign(event, @base, fd, flags, callback, data.as(Void*))
    end

    def loop(flags : LibEvent2::EventLoopFlags = :none)
      LibEvent2.event_base_loop(@base, flags)
    end

    def loop_break
      LibEvent2.event_base_loopbreak(@base)
    end

    def new_dns_base(init = true)
      DnsBase.new LibEvent2.evdns_base_new(@base, init ? 1 : 0)
    end

    def to_unsafe
      @base
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
