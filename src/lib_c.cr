{% if flag?(:win32) %}
  @[Link({{ flag?(:preview_dll) ? "ucrt" : "libucrt" }})]
{% end %}
lib LibC
  alias Char = UInt8
  alias UChar = Char
  alias SChar = Int8
  alias Short = Int16
  alias UShort = UInt16
  alias Int = Int32
  alias UInt = UInt32

  {% if flag?(:bits32) || flag?(:win32) %}
    alias Long = Int32
    alias ULong = UInt32
  {% elsif flag?(:bits64) %}
    alias Long = Int64
    alias ULong = UInt64
  {% else %}
    {% raise "Architecture with unsupported word size" %}
  {% end %}

  alias LongLong = Int64
  alias ULongLong = UInt64
  alias Float = Float32
  alias Double = Float64

  $environ : Char**
end
