require "c/errno"
require "c/string"

lib LibC
  ifdef linux
    ifdef musl
      fun __errno_location : Int*
    else
      @[ThreadLocal]
      $errno : Int
    end
  elsif darwin || freebsd
    fun __error : Int*
  end
end

# Errno wraps and gives access to libc's errno. This is mostly useful when
# dealing with C libraries.
#
# This class is the exception thrown when errno errors are encountered.
class Errno < Exception
  EPERM           = LibC::EPERM           # Operation not permitted
  ENOENT          = LibC::ENOENT          # No such file or directory
  ESRCH           = LibC::ESRCH           # No such process
  EINTR           = LibC::EINTR           # Interrupted system call
  EIO             = LibC::EIO             # Input/output error
  ENXIO           = LibC::ENXIO           # Device not configured
  ENOEXEC         = LibC::ENOEXEC         # Exec format error
  EBADF           = LibC::EBADF           # Bad file descriptor
  ECHILD          = LibC::ECHILD          # No child processes
  EDEADLK         = LibC::EDEADLK         # Resource deadlock avoided
  ENOMEM          = LibC::ENOMEM          # Cannot allocate memory
  EACCES          = LibC::EACCES          # Permission denied
  EFAULT          = LibC::EFAULT          # Bad address
  ENOTBLK         = LibC::ENOTBLK         # Block device required
  EBUSY           = LibC::EBUSY           # Device / Resource busy
  EEXIST          = LibC::EEXIST          # File exists
  EXDEV           = LibC::EXDEV           # Cross-device link
  ENODEV          = LibC::ENODEV          # Operation not supported by device
  ENOTDIR         = LibC::ENOTDIR         # Not a directory
  EISDIR          = LibC::EISDIR          # Is a directory
  EINVAL          = LibC::EINVAL          # Invalid argument
  ENFILE          = LibC::ENFILE          # Too many open files in system
  EMFILE          = LibC::EMFILE          # Too many open files
  ENOTTY          = LibC::ENOTTY          # Inappropriate ioctl for device
  ETXTBSY         = LibC::ETXTBSY         # Text file busy
  EFBIG           = LibC::EFBIG           # File too large
  ENOSPC          = LibC::ENOSPC          # No space left on device
  ESPIPE          = LibC::ESPIPE          # Illegal seek
  EROFS           = LibC::EROFS           # Read-only file system
  EMLINK          = LibC::EMLINK          # Too many links
  EPIPE           = LibC::EPIPE           # Broken pipe
  EDOM            = LibC::EDOM            # Numerical argument out of domain
  ERANGE          = LibC::ERANGE          # Result too large
  EAGAIN          = LibC::EAGAIN          # Resource temporarily unavailable
  EWOULDBLOCK     = LibC::EWOULDBLOCK     # Operation would block
  EINPROGRESS     = LibC::EINPROGRESS     # Operation now in progress
  EALREADY        = LibC::EALREADY        # Operation already in progress
  ENOTSOCK        = LibC::ENOTSOCK        # Socket operation on non-socket
  EDESTADDRREQ    = LibC::EDESTADDRREQ    # Destination address required
  EMSGSIZE        = LibC::EMSGSIZE        # Message too long
  EPROTOTYPE      = LibC::EPROTOTYPE      # Protocol wrong type for socket
  ENOPROTOOPT     = LibC::ENOPROTOOPT     # Protocol not available
  EPROTONOSUPPORT = LibC::EPROTONOSUPPORT # Protocol not supported
  ESOCKTNOSUPPORT = LibC::ESOCKTNOSUPPORT # Socket type not supported
  EPFNOSUPPORT    = LibC::EPFNOSUPPORT    # Protocol family not supported
  EAFNOSUPPORT    = LibC::EAFNOSUPPORT    # Address family not supported by protocol family
  EADDRINUSE      = LibC::EADDRINUSE      # Address already in use
  EADDRNOTAVAIL   = LibC::EADDRNOTAVAIL   # Can't assign requested address
  ENETDOWN        = LibC::ENETDOWN        # Network is down
  ENETUNREACH     = LibC::ENETUNREACH     # Network is unreachable
  ENETRESET       = LibC::ENETRESET       # Network dropped connection on reset
  ECONNABORTED    = LibC::ECONNABORTED    # Software caused connection abort
  ECONNRESET      = LibC::ECONNRESET      # Connection reset by peer
  ENOBUFS         = LibC::ENOBUFS         # No buffer space available
  EISCONN         = LibC::EISCONN         # Socket is already connected
  ENOTCONN        = LibC::ENOTCONN        # Socket is not connected
  ESHUTDOWN       = LibC::ESHUTDOWN       # Can't send after socket shutdown
  ETOOMANYREFS    = LibC::ETOOMANYREFS    # Too many references: can't splice
  ETIMEDOUT       = LibC::ETIMEDOUT       # Operation timed out
  ECONNREFUSED    = LibC::ECONNREFUSED    # Connection refused
  ELOOP           = LibC::ELOOP           # Too many levels of symbolic links
  ENAMETOOLONG    = LibC::ENAMETOOLONG    # File name too long
  EHOSTDOWN       = LibC::EHOSTDOWN       # Host is down
  EHOSTUNREACH    = LibC::EHOSTUNREACH    # No route to host
  ENOTEMPTY       = LibC::ENOTEMPTY       # Directory not empty
  EUSERS          = LibC::EUSERS          # Too many users
  EDQUOT          = LibC::EDQUOT          # Disc quota exceeded
  ESTALE          = LibC::ESTALE          # Stale NFS file handle
  EREMOTE         = LibC::EREMOTE         # Too many levels of remote in path
  ENOLCK          = LibC::ENOLCK          # No locks available
  ENOSYS          = LibC::ENOSYS          # Function not implemented
  EOVERFLOW       = LibC::EOVERFLOW       # Value too large to be stored in data type
  ECANCELED       = LibC::ECANCELED       # Operation canceled
  EIDRM           = LibC::EIDRM           # Identifier removed
  ENOMSG          = LibC::ENOMSG          # No message of desired type
  EILSEQ          = LibC::EILSEQ          # Illegal byte sequence
  EBADMSG         = LibC::EBADMSG         # Bad message
  EMULTIHOP       = LibC::EMULTIHOP       # Reserved
  ENODATA         = LibC::ENODATA         # No message available on STREAM
  ENOLINK         = LibC::ENOLINK         # Reserved
  ENOSR           = LibC::ENOSR           # No STREAM resources
  ENOSTR          = LibC::ENOSTR          # Not a STREAM
  EPROTO          = LibC::EPROTO          # Protocol error
  ETIME           = LibC::ETIME           # STREAM ioctl timeout
  EOPNOTSUPP      = LibC::EOPNOTSUPP      # Operation not supported on socket
  ENOTRECOVERABLE = LibC::ENOTRECOVERABLE # State not recoverable
  EOWNERDEAD      = LibC::EOWNERDEAD      # Previous owner died

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
  def initialize(message)
    errno = Errno.value
    @errno = errno
    super "#{message}: #{String.new(LibC.strerror(errno))}"
  end

  # Returns the value of libc's errno.
  def self.value : LibC::Int
    ifdef linux
      ifdef musl
        LibC.__errno_location.value
      else
        LibC.errno
      end
    elsif darwin || freebsd
      LibC.__error.value
    end
  end

  # Sets the value of libc's errno.
  def self.value=(value)
    ifdef linux
      ifdef musl
        LibC.__errno_location.value = value
      else
        LibC.errno = value
      end
    elsif darwin || freebsd
      LibC.__error.value = value
    end
  end
end
