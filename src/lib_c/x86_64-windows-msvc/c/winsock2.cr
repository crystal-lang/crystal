require "./ws2def"
require "./basetsd"
require "./guiddef"
require "./winbase"

@[Link("WS2_32")]
lib LibC
  alias SOCKET = UINT_PTR

  # -2147195266 is the value after conversion to long, actual value 2147772030 with type unsigned
  FIONBIO = -2147195266

  struct WSAData
    wVersion : WORD
    wHighVersion : WORD
    szDescription : Char[257]
    szSystemStatus : Char[129]
    iMaxSockets : UInt16
    iMaxUdpDg : UInt16
    lpVendorInfo : Char*
  end

  INVALID_SOCKET = ~SOCKET.new(0)
  SOCKET_ERROR   = -1

  SO_PROTOCOL_INFOW = 0x2005

  SOMAXCONN = 0x7fffffff

  FD_READ_BIT = 0
  FD_READ     = (1 << FD_READ_BIT)

  FD_WRITE_BIT = 1
  FD_WRITE     = (1 << FD_WRITE_BIT)

  FD_OOB_BIT = 2
  FD_OOB     = (1 << FD_OOB_BIT)

  FD_ACCEPT_BIT = 3
  FD_ACCEPT     = (1 << FD_ACCEPT_BIT)

  FD_CONNECT_BIT = 4
  FD_CONNECT     = (1 << FD_CONNECT_BIT)

  FD_CLOSE_BIT = 5
  FD_CLOSE     = (1 << FD_CLOSE_BIT)

  FD_QOS_BIT = 6
  FD_QOS     = (1 << FD_QOS_BIT)

  FD_GROUP_QOS_BIT = 7
  FD_GROUP_QOS     = (1 << FD_GROUP_QOS_BIT)

  FD_ROUTING_INTERFACE_CHANGE_BIT = 8
  FD_ROUTING_INTERFACE_CHANGE     = (1 << FD_ROUTING_INTERFACE_CHANGE_BIT)

  FD_ADDRESS_LIST_CHANGE_BIT = 9
  FD_ADDRESS_LIST_CHANGE     = (1 << FD_ADDRESS_LIST_CHANGE_BIT)

  FD_MAX_EVENTS = 10
  FD_ALL_EVENTS = ((1 << FD_MAX_EVENTS) - 1)

  alias WSAEVENT = HANDLE
  alias WSAOVERLAPPED = OVERLAPPED

  WSA_INVALID_EVENT       = Pointer(WSAEVENT).null
  WSA_MAXIMUM_WAIT_EVENTS = MAXIMUM_WAIT_OBJECTS
  WSA_WAIT_FAILED         = WAIT_FAILED
  WSA_WAIT_EVENT_0        = WAIT_OBJECT_0
  WSA_WAIT_IO_COMPLETION  = WAIT_IO_COMPLETION
  WSA_WAIT_TIMEOUT        = WAIT_TIMEOUT
  WSA_INFINITE            = INFINITE

  alias LPQOS = Void*

  SH_RECEIVE = 0x00
  SH_SEND    = 0x01
  SH_BOTH    = 0x02

  alias GROUP = Int

  struct WSAPROTOCOLCHAIN
    chainLen : Int
    chainEntries : DWORD*
  end

  struct WSAPROTOCOL_INFOW
    dwServiceFlags1 : DWORD
    dwServiceFlags2 : DWORD
    dwServiceFlags3 : DWORD
    dwServiceFlags4 : DWORD
    dwProviderFlags : DWORD
    providerId : GUID
    dwCatalogEntryId : DWORD
    protocolChain : WSAPROTOCOLCHAIN
    iVersion : Int
    iAddressFamily : Int
    iMaxSockAddr : Int
    iMinSockAddr : Int
    iSocketType : Int
    iProtocol : Int
    iProtocolMaxOffset : Int
    iNetworkByteOrder : Int
    iSecurityScheme : Int
    dwMessageSize : DWORD
    dwProviderReserved : DWORD
    szProtocol : WCHAR*
  end

  WSA_FLAG_OVERLAPPED = 0x01

  alias WSAOVERLAPPED_COMPLETION_ROUTINE = Proc(DWORD, DWORD, WSAOVERLAPPED*, DWORD, Void)

  struct Linger
    l_onoff : UShort
    l_linger : UShort
  end

  fun accept(s : SOCKET, addr : Sockaddr*, addrlen : Int*) : SOCKET
  fun bind(s : SOCKET, addr : Sockaddr*, namelen : Int) : Int
  fun closesocket(s : SOCKET) : Int
  fun connect(s : SOCKET, name : Sockaddr*, namelen : Int) : Int
  fun ioctlsocket(s : SOCKET, cmd : Int, argp : UInt32*) : Int
  fun getpeername(s : SOCKET, name : Sockaddr*, namelen : Int*) : Int
  fun getsockname(s : SOCKET, name : Sockaddr*, namelen : Int*) : Int
  fun getsockopt(s : SOCKET, level : Int, optname : Int, optval : UInt8*, optlen : Int*) : Int
  fun htons(hostshort : UShort) : UShort
  fun listen(s : SOCKET, backlog : Int) : Int
  fun ntohs(netshort : UShort) : UShort
  fun recv(s : SOCKET, buf : UInt8*, len : Int, flags : Int) : Int
  fun recvfrom(s : SOCKET, buf : Char*, len : Int, flags : Int, from : Sockaddr*, fromlen : Int*) : Int
  fun send(s : SOCKET, buf : UInt8*, len : Int, flags : Int) : Int
  fun setsockopt(s : SOCKET, level : Int, optname : Int, optval : Char*, len : Int) : Int
  fun shutdown(s : SOCKET, how : Int) : Int
  fun socket(af : Int, type : Int, protocol : Int) : SOCKET

  fun WSAStartup(wVersionRequired : WORD, lpWSAData : WSAData*) : Int
  fun WSACleanup : Int

  fun WSASetLastError(iError : Int) : Void
  fun WSAGetLastError : Int

  # Unused type
  alias LPCONDITIONPROC = Void*
  fun WSAAccept(
    s : SOCKET,
    addr : Sockaddr*,
    addrlen : Int*,
    lpfnCondition : LPCONDITIONPROC,
    dwCallbackData : DWORD*
  ) : SOCKET

  fun WSAConnect(
    s : SOCKET,
    name : Sockaddr*,
    namelen : Int,
    lpCallerData : WSABUF*,
    lpCalleeData : WSABUF*,
    lpSQOS : LPQOS,
    lpGQOS : LPQOS
  )
  fun WSACreateEvent : WSAEVENT

  fun WSAEventSelect(
    s : SOCKET,
    hEventObject : WSAEVENT,
    lNetworkEvents : Long
  ) : Int
  fun WSAGetOverlappedResult(
    s : SOCKET,
    lpOverlapped : WSAOVERLAPPED*,
    lpcbTransfer : DWORD*,
    fWait : BOOL,
    lpdwFlags : DWORD*
  ) : BOOL
  fun WSAIoctl(
    s : SOCKET,
    dwIoControlCode : DWORD,
    lpvInBuffer : Void*,
    cbInBuffer : DWORD,
    lpvOutBuffer : Void*,
    cbOutBuffer : DWORD,
    lpcbBytesReturned : DWORD*,
    lpOverlapped : WSAOVERLAPPED*,
    lpCompletionRoutine : WSAOVERLAPPED_COMPLETION_ROUTINE*
  ) : Int
  fun WSARecv(
    s : SOCKET,
    lpBuffers : WSABUF*,
    dwBufferCount : DWORD,
    lpNumberOfBytesRecvd : DWORD*,
    lpFlags : DWORD*,
    lpOverlapped : WSAOVERLAPPED*,
    lpCompletionRoutine : WSAOVERLAPPED_COMPLETION_ROUTINE*
  ) : Int
  fun WSARecvFrom(
    s : SOCKET,
    lpBuffers : WSABUF*,
    dwBufferCount : DWORD,
    lpNumberOfBytesRecvd : DWORD*,
    lpFlags : DWORD*,
    lpFrom : Sockaddr*,
    lpFromlen : Int*,
    lpOverlapped : WSAOVERLAPPED*,
    lpCompletionRoutine : WSAOVERLAPPED_COMPLETION_ROUTINE*
  ) : Int
  fun WSAResetEvent(
    hEvent : WSAEVENT
  ) : BOOL
  fun WSASend(
    s : SOCKET,
    lpBuffers : WSABUF*,
    dwBufferCount : DWORD,
    lpNumberOfBytesSent : DWORD*,
    dwFlags : DWORD,
    lpOverlapped : WSAOVERLAPPED*,
    lpCompletionRoutine : WSAOVERLAPPED_COMPLETION_ROUTINE*
  ) : Int
  fun WSASendTo(
    s : SOCKET,
    lpBuffers : WSABUF*,
    dwBufferCount : DWORD,
    lpNumberOfBytesSent : DWORD*,
    dwFlags : DWORD,
    lpTo : Sockaddr*,
    iTolen : Int,
    lpOverlapped : WSAOVERLAPPED*,
    lpCompletionRoutine : WSAOVERLAPPED_COMPLETION_ROUTINE*
  ) : Int
  fun WSASocketW(
    af : Int,
    type : Int,
    protocol : Int,
    lpProtocolInfo : WSAPROTOCOL_INFOW*,
    g : GROUP,
    dwFlags : DWORD
  ) : SOCKET
  fun WSAWaitForMultipleEvents(
    cEvents : DWORD,
    lphEvents : WSAEVENT*,
    fWaitAll : BOOL,
    dwTimeout : DWORD,
    fAlertable : BOOL
  ) : DWORD
end
