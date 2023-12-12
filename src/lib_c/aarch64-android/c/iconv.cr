require "./stddef"

lib LibC
  {% if ANDROID_API >= 28 %}
    type IconvT = Void*

    fun iconv(__converter : IconvT, __src_buf : Char**, __src_bytes_left : SizeT*, __dst_buf : Char**, __dst_bytes_left : SizeT*) : SizeT
    fun iconv_close(__converter : IconvT) : Int
    fun iconv_open(__src_encoding : Char*, __dst_encoding : Char*) : IconvT
  {% end %}
end
