require "../stddef"
require "../stdint"

lib LibC
  alias BlkcntT = Long
  alias BlksizeT = Int
  alias ClockT = Long
  alias ClockidT = Int
  alias DevT = ULong
  alias GidT = UInt
  alias IdT = UInt
  alias InoT = ULong
  alias ModeT = UInt
  alias NlinkT = UInt
  alias OffT = Long
  alias PidT = Int

  union PthreadAttrT
    __size : StaticArray(Char, 64)
    __align : Long
  end

  struct PthreadCondTData
    __lock : Int
    __futex : UInt
    __total_seq : ULongLong
    __wakeup_seq : ULongLong
    __woken_seq : ULongLong
    __mutex : Void*
    __nwaiters : UInt
    __broadcast_seq : UInt
  end

  union PthreadCondT
    __data : PthreadCondTData
    __size : StaticArray(Char, 48)
    __align : Long
  end

  union PthreadCondattrT
    __size : StaticArray(Char, 8)
    __align : Int
  end

  union PthreadMutexT
    __data : Void*
    __size : StaticArray(Char, 48)
    __align : Long
  end

  union PthreadMutexattrT
    __size : StaticArray(Char, 8)
    __align : Long
  end

  alias PthreadT = ULong
  alias SSizeT = Long
  alias SusecondsT = Long
  alias TimeT = Long
  alias UidT = UInt
end
