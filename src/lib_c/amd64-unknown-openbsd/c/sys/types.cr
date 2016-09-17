require "../stddef"
require "../stdint"

lib LibC
  alias BlkcntT = Long
  alias BlksizeT = UInt
  alias ClockT = Int
  alias ClockidT = Int
  alias DevT = UInt
  alias GidT = UInt
  alias IdT = Long
  alias InoT = UInt64
  alias ModeT = UInt32
  alias NlinkT = UShort
  alias OffT = Int64
  alias PidT = Int
  type PthreadAttrT = Void*
  type PthreadCondT = Void*
  type PthreadCondattrT = Void*
  type PthreadMutexT = Void*
  type PthreadMutexattrT = Void*
  type PthreadT = Void*
  alias SSizeT = Long
  alias SusecondsT = Long
  alias TimeT = Long
  alias UidT = UInt
end
