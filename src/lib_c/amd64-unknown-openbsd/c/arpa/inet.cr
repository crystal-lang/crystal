require "../netinet/in"
require "../stdint"

lib LibC
  fun htons(host16 : UInt16T) : UInt16T
  fun htonl(host32 : UInt32T) : UInt32T
  fun ntohs(net16 : UInt16T) : UInt16T
  fun ntohl(net32 : UInt32T) : UInt32T
  fun inet_ntop(af : Int, src : Void*, dst : Char*, size : SocklenT) : Char*
  fun inet_pton(af : Int, src : Char*, dst : Void*) : Int
end
