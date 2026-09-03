require "../netinet/in"
require "../stdint"

lib LibC
  {% if ANDROID_API >= 21 %}
    fun htons(__x : UInt16) : UInt16
    fun ntohs(__x : UInt16) : UInt16
  {% end %}
  fun inet_ntop(__af : Int, __src : Void*, __dst : Char*, __size : SocklenT) : Char*
  fun inet_pton(__af : Int, __src : Char*, __dst : Void*) : Int
end
