require "./winsock2"
require "./ws2ipdef"

lib LibC
  fun inet_ntop(family : Int, pAddr : Void*, pStringBuf : Char*, stringBufSize : SizeT) : Char*
  fun inet_pton(family : Int, pszAddrString : Char*, pAddrBuf : Void*) : Int
end
