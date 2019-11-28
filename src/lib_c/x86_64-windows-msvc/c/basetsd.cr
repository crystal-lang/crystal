require "./stddef"

lib LibC
  {% if flag?(:bits64) %}
    alias ULONG_PTR = UInt64
    alias SIZE_T = UInt64
  {% else %}
    alias ULONG_PTR = UInt32
    alias SIZE_T = UInt32
  {% end %}

  alias UINT = UInt32
  alias DWORD = UInt32
  alias BOOL = Int32
  alias BOOLEAN = BYTE
  alias BYTE = UChar
  alias LONG = Int32
  alias CHAR = UChar
  alias ULONG = UInt32
  alias ULONG64 = UInt64
  alias DWORD64 = UInt64
end
