@[Link("event")]
lib LibEvent2
  type EventBase = Void*
  type Event = Void*

  enum EventLoopFlags
    EVLOOP_ONCE = 0x01
    EVLOOP_NONBLOCK = 0x02
  end

  TIMEOUT = 0x01_u16
  READ = 0x02_u16
  WRITE = 0x04_u16
  SIGNAL = 0x08_u16
  PERSIST = 0x10_u16
  ET = 0x20_u16

  fun event_get_version : UInt8*
  fun event_base_new : EventBase
  fun event_base_dispatch(eb : EventBase) : Int32
  fun event_base_loop(eb : EventBase, flags : EventLoopFlags) : Int32
  fun event_base_loopbreak(eb : EventBase) : Int32
  fun event_set_log_callback(callback : (Int32, UInt8*) -> Nil)
  fun event_enable_debug_mode()
  fun event_new(eb : EventBase, s : Int32, events : UInt16, callback : (Int32, UInt16, Void*) ->, data : Void*) : Event
  fun event_add(event : Event, timeout : C::TimeVal*) : Int32
end
