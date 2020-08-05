require "../netinet/in"
require "../stdint"

lib LibC
  fun htons(hostshort : UInt16T) : UInt16T
  fun ntohs(netshort : UInt16T) : UInt16T
  fun inet_ntop(af : Int, cp : Void*, buf : Char*, len : SocklenT) : Char*
  fun inet_pton(af : Int, cp : Char*, buf : Void*) : Int
end
