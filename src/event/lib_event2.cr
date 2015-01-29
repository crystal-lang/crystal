@[Link("event")]
lib LibEvent2
  type EventBase = Void*
  type Event = Void*

  @[Flags]
  enum EventLoopFlags
    Once = 0x01
    NonBlock = 0x02
  end

  @[Flags]
  enum EventFlags
    Timeout = 0x01_u16
    Read = 0x02_u16
    Write = 0x04_u16
    Signal = 0x08_u16
    Persist = 0x10_u16
    ET = 0x20_u16
  end

  fun event_get_version : UInt8*
  fun event_base_new : EventBase
  fun event_base_dispatch(eb : EventBase) : Int32
  fun event_base_loop(eb : EventBase, flags : EventLoopFlags) : Int32
  fun event_base_loopbreak(eb : EventBase) : Int32
  fun event_set_log_callback(callback : (Int32, UInt8*) -> Nil)
  fun event_enable_debug_mode()
  fun event_new(eb : EventBase, s : Int32, events : EventFlags, callback : (Int32, EventFlags, Void*) ->, data : Void*) : Event
  fun event_add(event : Event, timeout : LibC::TimeVal*) : Int32
end
