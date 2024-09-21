lib LibC
  {% if flag?(:bits64) %}
    alias UINT_PTR = UInt64
    alias ULONG_PTR = UInt64
  {% else %}
    alias UINT_PTR = UInt32
    alias ULONG_PTR = Uint64
  {% end %}
end
