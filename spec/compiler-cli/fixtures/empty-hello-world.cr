lib LibC
  fun write(fd : Int32, buf : Void*, count : UInt32) : Int32
  fun exit(code : Int32) : NoReturn
  {% if flag?(:win32) %}
    fun _setmode(fd : Int32, mode : Int32) : Int32
  {% end %}
end

{% if flag?(:win32) %}
  LibC._setmode(1, 0x8000) # _O_BINARY
{% end %}

s = "hello world\n"
ret = LibC.write(1, pointerof(s.@c), s.@length)
LibC.exit(s.@length &- ret)
