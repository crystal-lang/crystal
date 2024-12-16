require "c/netdb"

# On musl systems, librt is empty. The entire library is already included in libc.
# On gnu systems, it's been integrated into `glibc` since 2.34 and it's not available
# as a shared library.
{% if flag?(:linux) && flag?(:gnu) && !flag?(:interpreted) && !flag?(:android) %}
  @[Link("rt")]
{% end %}

# Supported library versions:
#
# * libevent2
#
# See https://crystal-lang.org/reference/man/required_libraries.html#other-runtime-libraries
{% if flag?(:openbsd) %}
  @[Link("event_core")]
  @[Link("event_extra")]
{% else %}
  @[Link("event", pkg_config: "libevent")]
{% end %}
{% if flag?(:preview_mt) %}
  @[Link("event_pthreads", pkg_config: "libevent_pthreads")]
{% end %}
lib LibEvent2
  alias Int = LibC::Int

  alias EvutilSocketT = Int

  type EventBase = Void*
  type Event = Void*

  @[Flags]
  enum EventLoopFlags
    Once          = 0x01
    NonBlock      = 0x02
    NoExitOnEmpty = 0x04
  end

  @[Flags]
  enum EventFlags : LibC::Short
    Timeout = 0x01
    Read    = 0x02
    Write   = 0x04
    Signal  = 0x08
    Persist = 0x10
    ET      = 0x20
  end

  alias Callback = (EvutilSocketT, EventFlags, Void*) ->

  fun event_get_version : UInt8*
  fun event_base_new : EventBase
  fun event_base_dispatch(eb : EventBase) : Int
  fun event_base_loop(eb : EventBase, flags : EventLoopFlags) : Int
  fun event_base_loopbreak(eb : EventBase) : Int
  fun event_base_loopexit(EventBase, LibC::Timeval*) : LibC::Int
  fun event_set_log_callback(callback : (Int, UInt8*) -> Nil)
  fun event_enable_debug_mode
  fun event_reinit(eb : EventBase) : Int
  fun event_new(eb : EventBase, s : EvutilSocketT, events : EventFlags, callback : Callback, data : Void*) : Event
  fun event_free(event : Event)
  fun event_add(event : Event, timeout : LibC::Timeval*) : Int
  fun event_del(event : Event) : Int

  type DnsBase = Void*
  type DnsGetAddrinfoRequest = Void*

  EVUTIL_EAI_CANCEL = -90001

  alias DnsGetAddrinfoCallback = (Int32, LibC::Addrinfo*, Void*) ->

  fun evdns_base_new(base : EventBase, init : Int32) : DnsBase
  fun evdns_base_free(base : DnsBase, fail_requests : Int32)
  fun evdns_getaddrinfo(base : DnsBase, nodename : UInt8*, servname : UInt8*, hints : LibC::Addrinfo*, cb : DnsGetAddrinfoCallback, arg : Void*) : DnsGetAddrinfoRequest
  fun evdns_getaddrinfo_cancel(DnsGetAddrinfoRequest)
  fun evutil_freeaddrinfo(ai : LibC::Addrinfo*)

  {% if flag?(:preview_mt) %}
    fun evthread_use_pthreads : Int
  {% end %}
end
