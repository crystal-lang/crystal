require "../stddef"
require "../stdint"

lib LibC

  alias BlkcntT = LongLong
  alias BlksizeT = Int
  alias ClockT = LongLong
  alias ClockidT = Int
  alias DevT = Int
  alias GidT = UInt
  alias IdT = UInt
  alias InoT = ULongLong
  alias ModeT = UInt
  alias NlinkT = UInt
  alias OffT = LongLong
  alias PidT = Int

  type PthreadT = Void*

  struct PthreadAttrT
    pta_magic : UInt
    pta_flags : Int
    pta_private : Void*
  end

  struct PthreadQueueT
    ptqh_first : Void*
    ptqh_last : Void*
  end

  struct PthreadCondT
    ptc_magic : UInt
    ptc_lock : UInt8
    ptc_waiters : PthreadQueueT
    ptc_mutex : Void*
    ptc_private : Void*
  end

  struct PthreadCondattrT
    ptca_magic : UInt
    ptca_private : Void*
  end

  type PthreadKeyT = Int

  struct PthreadMutexT
    ptm_magic : UInt
    ptm_errorcheck : UInt8
    ptm_pad1 : UInt8[3]
    ptm_ceiling: UInt8
    ptm_pad2 : UInt8[2]
    ptm_owner: PthreadT
    ptm_waiters : PthreadT*
    ptm_recursed : UInt
    ptm_spare2 : Void*
  end

  struct PthreadMutexattrT
    ptma_magic : UInt
    ptma_private : Void*
  end

  alias SSizeT = Long
  alias SusecondsT = Long
  alias TimeT = LongLong
  alias UidT = UInt
end
