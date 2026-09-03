require "./sys/types"
require "./stddef"

lib LibC
  fun printf(__fmt : Char*, ...) : Int

  {% if ANDROID_API >= 21 %}
    fun dprintf(__fd : Int, __fmt : Char*, ...) : Int
  {% end %}

  fun rename(__old_path : Char*, __new_path : Char*) : Int
  fun snprintf(__buf : Char*, __size : SizeT, __fmt : Char*, ...) : Int
end
