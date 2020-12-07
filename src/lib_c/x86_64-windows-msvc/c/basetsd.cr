lib LibC
  {% if flag?(:bits64) %}
    alias ULONG_PTR = UInt64
  {% else %}
    alias ULONG_PTR = ULong
  {% end %}
end
