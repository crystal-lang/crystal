require "crystal/system/unix/errno"

# `OSError` is an exception that is raised when something goes wrong when using the operating
# system's API (for example, it can be based on libc's errno). More specific subclasses of it are
# available (see `OSError.create`).
#
# See also: `WindowsError`.
class OSError < Exception
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

  # Returns the error code from libc's `errno` that this exception is based on
  # (one of the constants in this module).
  getter errno : Int32

  # Returns the value of libc's errno.
  def self.errno : LibC::Int
    Crystal::System::Errno.value
  end

  # Sets the value of libc's errno.
  def self.errno=(value)
    Crystal::System::Errno.value = value
  end

  # :nodoc:
  def self.errno_to_class(errno) : OSError.class
    {% begin %}
      case errno
        {% for cls in OSError.all_subclasses %}
          {% for errno in cls.constant("ERRORS") || [] of ASTNode %}
            when {{errno}} then {{cls}}
          {% end %}
        {% end %}
      else OSError
      end
    {% end %}
  end

  def initialize(message, @errno)
    super(message)
  end

  # Creates an object of some subclass of `OSError` with the given message,
  # based on the *errno* code (the last set error by default).
  #
  # ```
  # if LibC.mkdir("foo/bar", mode) == -1
  #   raise OSError.create("Unable to create directory")
  #   # Actually a `OSError::FileNotFound` if "foo" does not exist.
  # end
  # ```
  def self.create(message = nil, errno = OSError.errno) : OSError
    cls = errno_to_class(errno)
    message ||= cls.name
    cls.new("#{message}: #{String.new(LibC.strerror(errno))}", errno)
  end

  class BlockingIO < OSError
    ERRORS = {EAGAIN, EALREADY, EINPROGRESS, EWOULDBLOCK}
  end

  class FileExists < OSError
    ERRORS = {EEXIST}
  end

  class FileNotFound < OSError
    ERRORS = {ENOENT}
  end

  class IsADirectory < OSError
    ERRORS = {EISDIR}
  end

  class NotADirectory < OSError
    ERRORS = {ENOTDIR}
  end

  class PermissionError < OSError
    ERRORS = {EACCES, EPERM}
  end
end

class ConnectionError < OSError
  class BrokenPipe < ConnectionError
    ERRORS = {EPIPE} # ESHUTDOWN is missing
  end

  class ConnectionAborted < ConnectionError
    ERRORS = {ECONNABORTED}
  end

  class ConnectionRefused < ConnectionError
    ERRORS = {ECONNREFUSED}
  end

  class ConnectionReset < ConnectionError
    ERRORS = {ECONNRESET}
  end
end
