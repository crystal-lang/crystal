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

i = 1
while i < ARGC_UNSAFE
  LibC.puts((ARGV_UNSAFE + i).value)
  i &+= 1
end

LibC.exit(0)
