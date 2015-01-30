lib LibC
  ifdef linux
    @[ThreadLocal]
    $errno : Int32
  else
    $errno : Int32
  end

  fun strerror(errnum : Int32) : UInt8*
end

class Errno < Exception
  ifdef darwin
    EPERM           = 1       # Operation not permitted
    ENOENT          = 2       # No such file or directory
    ESRCH           = 3       # No such process
    EINTR           = 4       # Interrupted system call
    EIO             = 5       # Input/output error
    ENXIO           = 6       # Device not configured
    ENOEXEC         = 8       # Exec format error
    EBADF           = 9       # Bad file descriptor
    ECHILD          = 10      # No child processes
    EDEADLK         = 11      # Resource deadlock avoided
    ENOMEM          = 12      # Cannot allocate memory
    EACCES          = 13      # Permission denied
    EFAULT          = 14      # Bad address
    ENOTBLK         = 15      # Block device required
    EBUSY           = 16      # Device / Resource busy
    EEXIST          = 17      # File exists
    EXDEV           = 18      # Cross-device link
    ENODEV          = 19      # Operation not supported by device
    ENOTDIR         = 20      # Not a directory
    EISDIR          = 21      # Is a directory
    EINVAL          = 22      # Invalid argument
    ENFILE          = 23      # Too many open files in system
    EMFILE          = 24      # Too many open files
    ENOTTY          = 25      # Inappropriate ioctl for device
    ETXTBSY         = 26      # Text file busy
    EFBIG           = 27      # File too large
    ENOSPC          = 28      # No space left on device
    ESPIPE          = 29      # Illegal seek
    EROFS           = 30      # Read-only file system
    EMLINK          = 31      # Too many links
    EPIPE           = 32      # Broken pipe
    EDOM            = 33      # Numerical argument out of domain
    ERANGE          = 34      # Result too large
    EAGAIN          = 35      # Resource temporarily unavailable
    EWOULDBLOCK     = EAGAIN  # Operation would block
    EINPROGRESS     = 36      # Operation now in progress
    EALREADY        = 37      # Operation already in progress
    ENOTSOCK        = 38      # Socket operation on non-socket
    EDESTADDRREQ    = 39      # Destination address required
    EMSGSIZE        = 40      # Message too long
    EPROTOTYPE      = 41      # Protocol wrong type for socket
    ENOPROTOOPT     = 42      # Protocol not available
    EPROTONOSUPPORT = 43      # Protocol not supported
    ESOCKTNOSUPPORT = 44      # Socket type not supported
    EPFNOSUPPORT    = 46      # Protocol family not supported
    EAFNOSUPPORT    = 47      # Address family not supported by protocol family
    EADDRINUSE      = 48      # Address already in use
    EADDRNOTAVAIL   = 49      # Can't assign requested address
    ENETDOWN        = 50      # Network is down
    ENETUNREACH     = 51      # Network is unreachable
    ENETRESET       = 52      # Network dropped connection on reset
    ECONNABORTED    = 53      # Software caused connection abort
    ECONNRESET      = 54      # Connection reset by peer
    ENOBUFS         = 55      # No buffer space available
    EISCONN         = 56      # Socket is already connected
    ENOTCONN        = 57      # Socket is not connected
    ESHUTDOWN       = 58      # Can't send after socket shutdown
    ETOOMANYREFS    = 59      # Too many references: can't splice
    ETIMEDOUT       = 60      # Operation timed out
    ECONNREFUSED    = 61      # Connection refused
    ELOOP           = 62      # Too many levels of symbolic links
    ENAMETOOLONG    = 63      # File name too long
    EHOSTDOWN       = 64      # Host is down
    EHOSTUNREACH    = 65      # No route to host
    ENOTEMPTY       = 66      # Directory not empty
    EUSERS          = 68      # Too many users
    EDQUOT          = 69      # Disc quota exceeded
    ESTALE          = 70      # Stale NFS file handle
    EREMOTE         = 71      # Too many levels of remote in path
    ENOLCK          = 77      # No locks available
    ENOSYS          = 78      # Function not implemented
    EOVERFLOW       = 84      # Value too large to be stored in data type
    ECANCELED       = 89      # Operation canceled
    EIDRM           = 90      # Identifier removed
    ENOMSG          = 91      # No message of desired type
    EILSEQ          = 92      # Illegal byte sequence
    EBADMSG         = 94      # Bad message
    EMULTIHOP       = 95      # Reserved
    ENODATA         = 96      # No message available on STREAM
    ENOLINK         = 97      # Reserved
    ENOSR           = 98      # No STREAM resources
    ENOSTR          = 99      # Not a STREAM
    EPROTO          = 100     # Protocol error
    ETIME           = 101     # STREAM ioctl timeout
    EOPNOTSUPP      = 102     # Operation not supported on socket
    ENOTRECOVERABLE = 104     # State not recoverable
    EOWNERDEAD      = 105     # Previous owner died
  else
    EPERM           = 1       # Operation not permitted
    ENOENT          = 2       # No such file or directory
    ESRCH           = 3       # No such process
    EINTR           = 4       # Interrupted system call
    EIO             = 5       # I/O error
    ENXIO           = 6       # No such device or address
    ENOEXEC         = 8       # Exec format error
    EBADF           = 9       # Bad file number
    ECHILD          = 10      # No child processes
    EAGAIN          = 11      # Try again
    ENOMEM          = 12      # Out of memory
    EACCES          = 13      # Permission denied
    EFAULT          = 14      # Bad address
    ENOTBLK         = 15      # Block device required
    EBUSY           = 16      # Device or resource busy
    EEXIST          = 17      # File exists
    EXDEV           = 18      # Cross-device link
    ENODEV          = 19      # No such device
    ENOTDIR         = 20      # Not a directory
    EISDIR          = 21      # Is a directory
    EINVAL          = 22      # Invalid argument
    ENFILE          = 23      # File table overflow
    EMFILE          = 24      # Too many open files
    ENOTTY          = 25      # Not a typewriter
    ETXTBSY         = 26      # Text file busy
    EFBIG           = 27      # File too large
    ENOSPC          = 28      # No space left on device
    ESPIPE          = 29      # Illegal seek
    EROFS           = 30      # Read-only file system
    EMLINK          = 31      # Too many links
    EPIPE           = 32      # Broken pipe
    EDOM            = 33      # Math argument out of domain of func
    ERANGE          = 34      # Math result not representable
    EDEADLK         = 35      # Resource deadlock would occur
    ENAMETOOLONG    = 36      # File name too long
    ENOLCK          = 37      # No record locks available
    ENOSYS          = 38      # Function not implemented
    ENOTEMPTY       = 39      # Directory not empty
    ELOOP           = 40      # Too many symbolic links encountered
    EWOULDBLOCK     = EAGAIN  # Operation would block
    ENOMSG          = 42      # No message of desired type
    EIDRM           = 43      # Identifier removed
    ENOSTR          = 60      # Device not a stream
    ENODATA         = 61      # No data available
    ETIME           = 62      # Timer expired
    ENOSR           = 63      # Out of streams resources
    EREMOTE         = 66      # Object is remote
    ENOLINK         = 67      # Link has been severed
    EPROTO          = 71      # Protocol error
    EMULTIHOP       = 72      # Multihop attempted
    EBADMSG         = 74      # Not a data message
    EOVERFLOW       = 75      # Value too large for defined data type
    EILSEQ          = 84      # Illegal byte sequence
    EUSERS          = 87      # Too many users
    ENOTSOCK        = 88      # Socket operation on non-socket
    EDESTADDRREQ    = 89      # Destination address required
    EMSGSIZE        = 90      # Message too long
    EPROTOTYPE      = 91      # Protocol wrong type for socket
    ENOPROTOOPT     = 92      # Protocol not available
    EPROTONOSUPPORT = 93      # Protocol not supported
    ESOCKTNOSUPPORT = 94      # Socket type not supported
    EOPNOTSUPP      = 95      # Operation not supported on transport endpoint
    EPFNOSUPPORT    = 96      # Protocol family not supported
    EAFNOSUPPORT    = 97      # Address family not supported by protocol
    EADDRINUSE      = 98      # Address already in use
    EADDRNOTAVAIL   = 99      # Cannot assign requested address
    ENETDOWN        = 100     # Network is down
    ENETUNREACH     = 101     # Network is unreachable
    ENETRESET       = 102     # Network dropped connection because of reset
    ECONNABORTED    = 103     # Software caused connection abort
    ECONNRESET      = 104     # Connection reset by peer
    ENOBUFS         = 105     # No buffer space available
    EISCONN         = 106     # Transport endpoint is already connected
    ENOTCONN        = 107     # Transport endpoint is not connected
    ESHUTDOWN       = 108     # Cannot send after transport endpoint shutdown
    ETOOMANYREFS    = 109     # Too many references: cannot splice
    ETIMEDOUT       = 110     # Connection timed out
    ECONNREFUSED    = 111     # Connection refused
    EHOSTDOWN       = 112     # Host is down
    EHOSTUNREACH    = 113     # No route to host
    EALREADY        = 114     # Operation already in progress
    EINPROGRESS     = 115     # Operation now in progress
    ESTALE          = 116     # Stale NFS file handle
    EDQUOT          = 122     # Quota exceeded
    ECANCELED       = 125     # Operation Canceled
    EOWNERDEAD      = 130     # Owner died
    ENOTRECOVERABLE = 131     # State not recoverable
  end

  getter errno

  def initialize(message)
    errno = LibC.errno
    @errno = errno
    super "#{message}: #{String.new(LibC.strerror(errno))}"
  end
end
