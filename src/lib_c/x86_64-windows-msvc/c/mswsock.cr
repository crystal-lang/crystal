require "./guiddef"

@[Link("mswsock")]
lib LibC
  SO_UPDATE_ACCEPT_CONTEXT  = 0x700B
  SO_UPDATE_CONNECT_CONTEXT = 0x7010

  alias AcceptEx = Proc(SOCKET, SOCKET, Void*, DWORD, DWORD, DWORD, DWORD*, OVERLAPPED*, BOOL)
  WSAID_ACCEPTEX = GUID.new(0xb5367df1, 0xcbac, 0x11cf, UInt8.static_array(0x95, 0xca, 0x00, 0x80, 0x5f, 0x48, 0xa1, 0x92))

  alias ConnectEx = Proc(SOCKET, Sockaddr*, Int, Void*, DWORD, DWORD*, OVERLAPPED*, BOOL)
  WSAID_CONNECTEX = GUID.new(0x25a207b9, 0xddf3, 0x4660, UInt8.static_array(0x8e, 0xe9, 0x76, 0xe5, 0x8c, 0x74, 0x06, 0x3e))
end
