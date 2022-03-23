require "../stddef"
require "../stdint"

lib LibC
  alias BlkcntT = Int64
  alias BlksizeT = Int32
  alias ClockT = UInt
  alias ClockidT = Int
  alias DevT = UInt64
  alias GidT = UInt32
  alias IdT = UInt32
  alias InoT = UInt64
  alias ModeT = UInt32
  alias NlinkT = UInt32
  alias OffT = Int64
  alias PidT = Int32

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
    ptm_ceiling : UInt8
    ptm_pad2 : UInt8[2]
    ptm_owner : PthreadT
    ptm_waiters : PthreadT*
    ptm_recursed : UInt
    ptm_spare2 : Void*
  end

  struct PthreadMutexattrT
    ptma_magic : UInt
    ptma_private : Void*
  end

  alias SSizeT = Long
  alias SusecondsT = UInt
  alias TimeT = Int64
  alias UidT = UInt32
end
