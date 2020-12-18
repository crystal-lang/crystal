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
  {% if flag?(:freebsd11) %}
    alias InoT = UInt
  {% else %}
    alias InoT = ULong
  {% end %}
  alias ModeT = UShort
  {% if flag?(:freebsd11) %}
    alias NlinkT = UShort
  {% else %}
    alias NlinkT = ULong
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
