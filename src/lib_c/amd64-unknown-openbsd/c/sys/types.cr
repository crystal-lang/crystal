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
  type PthreadAttrT = Void*
  type PthreadCondT = Void*
  type PthreadCondattrT = Void*
  type PthreadMutexT = Void*
  type PthreadMutexattrT = Void*
  type PthreadT = Void*
  alias SSizeT = Long
  alias SusecondsT = Long
  alias TimeT = LongLong
  alias UidT = UInt
end
