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
  {% if flag?(:"freebsd12.0") %}
    alias InoT = ULong
  {% else %}
    alias InoT = UInt
  {% end %}
  alias ModeT = UShort
  {% if flag?(:"freebsd12.0") %}
    alias NlinkT = ULong
  {% else %}
    alias NlinkT = UShort
  {% end %}
  alias OffT = Long
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
