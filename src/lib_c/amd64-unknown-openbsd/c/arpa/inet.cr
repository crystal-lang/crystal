require "../netinet/in"
require "../stdint"

lib LibC
  fun htons(x0 : UInt16T) : UInt16T
  fun ntohs(x0 : UInt16T) : UInt16T
  fun inet_ntop(x0 : Int, x1 : Void*, x2 : Char*, x3 : SocklenT) : Char*
  fun inet_pton(x0 : Int, x1 : Char*, x2 : Void*) : Int
end
