require "../winnt"

lib LibC
  fun inet_ntop(family : INT, pAddr : PVOID, pStringBuf : PSTR, stringBufSize : SizeT) : PCSTR
  fun inet_pton(family : INT, pszAddrString : PCSTR, pAddrBuf : PVOID) : INT
end
