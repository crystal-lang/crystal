lib LibC
  {% if ANDROID_API >= 28 %}
    GRND_NONBLOCK = 1_u32

    fun getrandom(buf : Void*, buflen : SizeT, flags : UInt32) : SSizeT
  {% end %}
end
