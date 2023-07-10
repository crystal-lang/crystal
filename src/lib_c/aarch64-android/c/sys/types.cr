require "../stddef"
require "../stdint"

lib LibC
  alias BlkcntT = ULong
  alias BlksizeT = ULong
  alias ClockT = Long
  alias ClockidT = Int
  alias DevT = UInt64
  alias GidT = UInt
  alias IdT = UInt32
  alias InoT = ULong
  alias ModeT = UInt
  alias NlinkT = UInt32
  alias OffT = Int64
  alias PidT = Int

  struct PthreadAttrT
    flags : UInt32
    stack_base : Void*
    stack_size : SizeT
    guard_size : SizeT
    sched_policy : Int32
    sched_priority : Int32
    __reserved : Char[16]
  end

  struct PthreadCondT
    __private : Int32[12]
  end

  alias PthreadCondattrT = Long

  struct PthreadMutexT
    __private : Int32[10]
  end

  alias PthreadMutexattrT = Long
  alias PthreadT = Long
  alias SSizeT = Long
  alias SusecondsT = Long
  alias TimeT = Long
  alias UidT = UInt
end
