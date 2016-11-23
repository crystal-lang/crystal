require "../stddef"
require "../stdint"

lib LibC
  alias BlkcntT = ULong
  alias BlksizeT = ULong
  alias ClockT = Long
  alias ClockidT = Int
  alias DevT = UInt64T
  alias GidT = UInt
  alias IdT = UInt32T
  alias InoT = ULong
  alias ModeT = UShort
  alias NlinkT = UInt32T
  alias OffT = Long
  alias PidT = Int

  struct PthreadAttrT
    flags : UInt32T
    stack_base : Void*
    stack_size : SizeT
    guard_size : SizeT
    sched_policy : Int32T
    __sched_priority : Int32T
    __reserved : StaticArray(Char, 16)
  end

  struct PthreadCondT
    value : Int
    __reserved : StaticArray(Char, 44)
  end

  alias PthreadCondattrT = Long

  struct PthreadMutexT
    value : Int
    __reserved : StaticArray(Char, 36)
  end

  alias PthreadMutexattrT = Long
  alias PthreadT = Long
  alias SSizeT = Int
  alias SusecondsT = Long
  alias TimeT = Long
  alias UidT = UInt
end
