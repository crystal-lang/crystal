require "c/errno"
require "c/string"

lib LibC
  {% if flag?(:linux) %}
    {% if flag?(:musl) %}
      fun __errno_location : Int*
    {% else %}
      @[ThreadLocal]
      $errno : Int
    {% end %}
  {% elsif flag?(:darwin) || flag?(:freebsd) %}
    fun __error : Int*
  {% elsif flag?(:openbsd) %}
    fun __error = __errno : Int*
  {% end %}
end

# Errno wraps and gives access to libc's errno. This is mostly useful when
# dealing with C libraries.
#
# This class is the exception thrown when errno errors are encountered.
class Errno < Exception
  # Argument list too long
  E2BIG = LibC::E2BIG
  # Operation not permitted
  EPERM = LibC::EPERM
  # No such file or directory
  ENOENT = LibC::ENOENT
  # No such process
  ESRCH = LibC::ESRCH
  # Interrupted system call
  EINTR = LibC::EINTR
  # Input/output error
  EIO = LibC::EIO
  # Device not configured
  ENXIO = LibC::ENXIO
  # Exec format error
  ENOEXEC = LibC::ENOEXEC
  # Bad file descriptor
  EBADF = LibC::EBADF
  # No child processes
  ECHILD = LibC::ECHILD
  # Resource deadlock avoided
  EDEADLK = LibC::EDEADLK
  # Cannot allocate memory
  ENOMEM = LibC::ENOMEM
  # Permission denied
  EACCES = LibC::EACCES
  # Bad address
  EFAULT = LibC::EFAULT
  # Block device required
  ENOTBLK = LibC::ENOTBLK
  # Device / Resource busy
  EBUSY = LibC::EBUSY
  # File exists
  EEXIST = LibC::EEXIST
  # Cross-device link
  EXDEV = LibC::EXDEV
  # Operation not supported by device
  ENODEV = LibC::ENODEV
  # Not a directory
  ENOTDIR = LibC::ENOTDIR
  # Is a directory
  EISDIR = LibC::EISDIR
  # Invalid argument
  EINVAL = LibC::EINVAL
  # Too many open files in system
  ENFILE = LibC::ENFILE
  # Too many open files
  EMFILE = LibC::EMFILE
  # Inappropriate ioctl for device
  ENOTTY = LibC::ENOTTY
  # Text file busy
  ETXTBSY = LibC::ETXTBSY
  # File too large
  EFBIG = LibC::EFBIG
  # No space left on device
  ENOSPC = LibC::ENOSPC
  # Illegal seek
  ESPIPE = LibC::ESPIPE
  # Read-only file system
  EROFS = LibC::EROFS
  # Too many links
  EMLINK = LibC::EMLINK
  # Broken pipe
  EPIPE = LibC::EPIPE
  # Numerical argument out of domain
  EDOM = LibC::EDOM
  # Result too large
  ERANGE = LibC::ERANGE
  # Resource temporarily unavailable
  EAGAIN = LibC::EAGAIN
  # Operation would block
  EWOULDBLOCK = LibC::EWOULDBLOCK
  # Operation now in progress
  EINPROGRESS = LibC::EINPROGRESS
  # Operation already in progress
  EALREADY = LibC::EALREADY
  # Socket operation on non-socket
  ENOTSOCK = LibC::ENOTSOCK
  # Destination address required
  EDESTADDRREQ = LibC::EDESTADDRREQ
  # Message too long
  EMSGSIZE = LibC::EMSGSIZE
  # Protocol wrong type for socket
  EPROTOTYPE = LibC::EPROTOTYPE
  # Protocol not available
  ENOPROTOOPT = LibC::ENOPROTOOPT
  # Protocol not supported
  EPROTONOSUPPORT = LibC::EPROTONOSUPPORT
  # Socket type not supported
  ESOCKTNOSUPPORT = LibC::ESOCKTNOSUPPORT
  # Protocol family not supported
  EPFNOSUPPORT = LibC::EPFNOSUPPORT
  # Address family not supported by protocol family
  EAFNOSUPPORT = LibC::EAFNOSUPPORT
  # Address already in use
  EADDRINUSE = LibC::EADDRINUSE
  # Can't assign requested address
  EADDRNOTAVAIL = LibC::EADDRNOTAVAIL
  # Network is down
  ENETDOWN = LibC::ENETDOWN
  # Network is unreachable
  ENETUNREACH = LibC::ENETUNREACH
  # Network dropped connection on reset
  ENETRESET = LibC::ENETRESET
  # Software caused connection abort
  ECONNABORTED = LibC::ECONNABORTED
  # Connection reset by peer
  ECONNRESET = LibC::ECONNRESET
  # No buffer space available
  ENOBUFS = LibC::ENOBUFS
  # Socket is already connected
  EISCONN = LibC::EISCONN
  # Socket is not connected
  ENOTCONN = LibC::ENOTCONN
  # Can't send after socket shutdown
  ESHUTDOWN = LibC::ESHUTDOWN
  # Too many references: can't splice
  ETOOMANYREFS = LibC::ETOOMANYREFS
  # Operation timed out
  ETIMEDOUT = LibC::ETIMEDOUT
  # Connection refused
  ECONNREFUSED = LibC::ECONNREFUSED
  # Too many levels of symbolic links
  ELOOP = LibC::ELOOP
  # File name too long
  ENAMETOOLONG = LibC::ENAMETOOLONG
  # Host is down
  EHOSTDOWN = LibC::EHOSTDOWN
  # No route to host
  EHOSTUNREACH = LibC::EHOSTUNREACH
  # Directory not empty
  ENOTEMPTY = LibC::ENOTEMPTY
  # Too many users
  EUSERS = LibC::EUSERS
  # Disc quota exceeded
  EDQUOT = LibC::EDQUOT
  # Stale NFS file handle
  ESTALE = LibC::ESTALE
  # Too many levels of remote in path
  EREMOTE = LibC::EREMOTE
  # No locks available
  ENOLCK = LibC::ENOLCK
  # Function not implemented
  ENOSYS = LibC::ENOSYS
  # Value too large to be stored in data type
  EOVERFLOW = LibC::EOVERFLOW
  # Operation canceled
  ECANCELED = LibC::ECANCELED
  # Identifier removed
  EIDRM = LibC::EIDRM
  # No message of desired type
  ENOMSG = LibC::ENOMSG
  # Illegal byte sequence
  EILSEQ = LibC::EILSEQ
  # Bad message
  EBADMSG = LibC::EBADMSG
  # Reserved
  EMULTIHOP = LibC::EMULTIHOP
  # No message available on STREAM
  ENODATA = LibC::ENODATA
  # Reserved
  ENOLINK = LibC::ENOLINK
  # No STREAM resources
  ENOSR = LibC::ENOSR
  # Not a STREAM
  ENOSTR = LibC::ENOSTR
  # Protocol error
  EPROTO = LibC::EPROTO
  # STREAM ioctl timeout
  ETIME = LibC::ETIME
  # Operation not supported on socket
  EOPNOTSUPP = LibC::EOPNOTSUPP
  # State not recoverable
  ENOTRECOVERABLE = LibC::ENOTRECOVERABLE
  # Previous owner died
  EOWNERDEAD = LibC::EOWNERDEAD

  # Returns the numeric value of errno.
  getter errno : Int32

  # Creates a new Errno with the given message. The message will
  # have concatenated the message denoted by `Errno#value`.
  #
  # Typical usage:
  #
  # ```
  # err = LibC.some_call
  # if err == -1
  #   raise Errno.new("some_call")
  # end
  # ```
  def initialize(message, errno = Errno.value)
    @errno = errno
    super "#{message}: #{String.new(LibC.strerror(errno))}"
  end

  # Returns the value of libc's errno.
  def self.value : LibC::Int
    {% if flag?(:linux) %}
      {% if flag?(:musl) %}
        LibC.__errno_location.value
      {% else %}
        LibC.errno
      {% end %}
    {% elsif flag?(:darwin) || flag?(:freebsd) || flag?(:openbsd) %}
      LibC.__error.value
    {% end %}
  end

  # Sets the value of libc's errno.
  def self.value=(value)
    {% if flag?(:linux) %}
      {% if flag?(:musl) %}
        LibC.__errno_location.value = value
      {% else %}
        LibC.errno = value
      {% end %}
    {% elsif flag?(:darwin) || flag?(:freebsd) || flag?(:openbsd) %}
      LibC.__error.value = value
    {% end %}
  end
end
