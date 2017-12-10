require "c/netdb"

{% if flag?(:linux) %}
  @[Link("rt")]
{% end %}

{% if flag?(:openbsd) %}
@[Link("event_core")]
@[Link("event_extra")]
{% else %}
@[Link("event")]
{% end %}
lib LibEvent2
  alias Char = LibC::Char
  alias Int = LibC::Int

  {% if flag?(:windows) %}
    # TODO
  {% else %}
    alias EvutilSocketT = Int
  {% end %}

  type EventBase = Void*
  type Event = Void*

  @[Flags]
  enum EventLoopFlags
    Once     = 0x01
    NonBlock = 0x02
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
  fun event_set_log_callback(callback : (Int, UInt8*) -> Nil)
  fun event_enable_debug_mode
  fun event_reinit(eb : EventBase) : Int
  fun event_new(eb : EventBase, s : EvutilSocketT, events : EventFlags, callback : Callback, data : Void*) : Event
  fun event_free(event : Event)
  fun event_add(event : Event, timeout : LibC::Timeval*) : Int
  fun event_del(event : Event) : Int

  {% if flag?(:windows) %}
    struct EvutilAddrinfo
      ai_flags : Int
      ai_family : Int
      ai_socktype : Int
      ai_protocol : Int
      ai_addrlen : LibC::SizeT
      ai_canonname : Char*
      ai_addr : LibC::Sockaddr*
      ai_next : EvutilAddrinfo*
    end

    EVUTIL_AI_NUMERICSERV = 0x8000
  {% else %}
    alias EvutilAddrinfo = LibC::Addrinfo

    EVUTIL_AI_NUMERICSERV = LibC::AI_NUMERICSERV
  {% end %}

  EVUTIL_EAI_CANCEL = -90001

  type EvdnsBase = Void*
  type EvdnsGetaddrinfoRequest = Void*

  alias EvdnsGetaddrinfoCallback = (Int, EvutilAddrinfo*, Void*) ->

  fun evdns_base_new(event_base : EventBase, initialize : Int) : EvdnsBase
  fun evdns_base_free(base : EvdnsBase, fail_requests : Int)
  fun evdns_getaddrinfo(dns_base : EvdnsBase, nodename : Char*, servname : Char*, hints_in : EvutilAddrinfo*, cb : EvdnsGetaddrinfoCallback, arg : Void*) : EvdnsGetaddrinfoRequest
  fun evdns_getaddrinfo_cancel(req : EvdnsGetaddrinfoRequest) : Void
  fun evutil_freeaddrinfo(ai : EvutilAddrinfo*) : Void
  fun evutil_gai_strerror(err : Int) : Char*
end
