lib LibC
  alias Char = UInt8
  alias UChar = Char
  alias SChar = Int8
  alias Short = Int16
  alias UShort = UInt16
  alias Int = Int32
  alias UInt = UInt32

  {% if flag?(:x86_64) || flag?(:aarch64) %}
    alias Long = Int64
    alias ULong = UInt64
  {% elsif flag?(:i686) || flag?(:arm) %}
    alias Long = Int32
    alias ULong = UInt32
  {% end %}

  alias LongLong = Int64
  alias ULongLong = UInt64
  alias Float = Float32
  alias Double = Float64

  $environ : Char**
end
