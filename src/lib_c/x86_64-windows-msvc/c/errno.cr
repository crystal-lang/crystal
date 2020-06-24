lib LibC
  # source https://docs.microsoft.com/en-us/cpp/c-runtime-library/errno-doserrno-sys-errlist-and-sys-nerr
  EPERM        =  1
  ENOENT       =  2
  ESRCH        =  3
  EINTR        =  4
  EIO          =  5
  ENXIO        =  6
  E2BIG        =  7
  ENOEXEC      =  8
  EBADF        =  9
  ECHILD       = 10
  EAGAIN       = 11
  ENOMEM       = 12
  EACCES       = 13
  EFAULT       = 14
  EBUSY        = 16
  EEXIST       = 17
  EXDEV        = 18
  ENODEV       = 19
  ENOTDIR      = 20
  EISDIR       = 21
  EINVAL       = 22
  ENFILE       = 23
  EMFILE       = 24
  ENOTTY       = 25
  EFBIG        = 27
  ENOSPC       = 28
  ESPIPE       = 29
  EROFS        = 30
  EMLINK       = 31
  EPIPE        = 32
  EDOM         = 33
  ERANGE       = 34
  EDEADLK      = 36
  ENAMETOOLONG = 38
  ENOLCK       = 39
  ENOSYS       = 40
  ENOTEMPTY    = 41
  EILSEQ       = 42
  STRUNCATE    = 80

  # source https://docs.microsoft.com/en-us/windows/win32/winsock/windows-sockets-error-codes-2
  WSAECONNABORTED = 10053
  ECONNABORTED = 10053
  WSAECONNRESET = 10054
  ECONNRESET = 10054
  WSAECONNREFUSED = 10061
  ECONNREFUSED = 10061
  WSAEADDRINUSE = 10048
  EADDRINUSE = 10048

  WSABASEERR = 10000
  WSAEINPROGRESS = WSABASEERR + 36
  WSAEINTR = WSABASEERR + 4

  EISCONN = 106
  EALREADY = 114
  EINPROGRESS = 115

  alias ErrnoT = Int
end
