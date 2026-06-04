lib LibC
  fun puts(str : UInt8*) : Int32
  fun exit(code : Int32) : NoReturn
  {% if flag?(:win32) %}
    fun _setmode(fd : Int32, mode : Int32) : Int32
  {% end %}
end

{% if flag?(:win32) %}
  LibC._setmode(1, 0x8000) # _O_BINARY
{% end %}

s = "hello world"
ret = LibC.puts(pointerof(s.@c))
LibC.exit(ret < 0 ? 1 : 0)
