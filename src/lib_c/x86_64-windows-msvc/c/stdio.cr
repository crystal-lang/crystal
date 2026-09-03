require "./stddef"

{% if flag?(:msvc) %}
  @[Link("legacy_stdio_definitions")]
{% end %}
lib LibC
  # unused
  fun printf(format : Char*, ...) : Int
  fun rename(old : Char*, new : Char*) : Int
  fun snprintf(buffer : Char*, count : SizeT, format : Char*, ...) : Int
end
