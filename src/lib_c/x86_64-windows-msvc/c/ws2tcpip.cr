require "./winsock2"
require "./ws2ipdef"

lib LibC
  EAI_AGAIN        = WinError::WSATRY_AGAIN
  EAI_BADFLAGS     = WinError::WSAEINVAL
  EAI_FAIL         = WinError::WSANO_RECOVERY
  EAI_FAMILY       = WinError::WSAEAFNOSUPPORT
  EAI_MEMORY       = WinError::WSA_NOT_ENOUGH_MEMORY
  EAI_NOSECURENAME = WinError::WSA_SECURE_HOST_NOT_FOUND
  EAI_NONAME       = WinError::WSAHOST_NOT_FOUND
  EAI_SERVICE      = WinError::WSATYPE_NOT_FOUND
  EAI_SOCKTYPE     = WinError::WSAESOCKTNOSUPPORT
  EAI_IPSECPOLICY  = WinError::WSA_IPSEC_NAME_POLICY_ERROR

  fun freeaddrinfo(pAddrInfo : Addrinfo*) : Void
  fun getaddrinfo(pNodeName : Char*, pServiceName : Char*, pHints : Addrinfo*, ppResult : Addrinfo**) : Int
  fun inet_ntop(family : Int, pAddr : Void*, pStringBuf : Char*, stringBufSize : SizeT) : Char*
  fun inet_pton(family : Int, pszAddrString : Char*, pAddrBuf : Void*) : Int
end
