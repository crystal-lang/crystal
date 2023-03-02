require "./stddef"

{% if flag?(:interpreted) %}
  @[Link("win32_interpreter_stub")]
  lib LibC
    fun printf = __crystal_printf(format : Char*, ...) : Int
    fun snprintf = __crystal_snprintf(buffer : Char*, count : SizeT, format : Char*, ...) : Int
  end
{% else %}
  @[Link("legacy_stdio_definitions")]
  lib LibC
    fun printf(format : Char*, ...) : Int
    fun snprintf(buffer : Char*, count : SizeT, format : Char*, ...) : Int
  end
{% end %}

lib LibC
  fun rename(old : Char*, new : Char*) : Int
end
