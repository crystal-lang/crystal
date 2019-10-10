require "c/errno"
require "c/string"

lib LibC
  {% if flag?(:linux) %}
    fun __errno_location : Int*
  {% elsif flag?(:darwin) || flag?(:freebsd) %}
    fun __error : Int*
  {% elsif flag?(:openbsd) %}
    fun __error = __errno : Int*
  {% elsif flag?(:win32) %}
    fun _get_errno(value : Int*) : ErrnoT
    fun _set_errno(value : Int) : ErrnoT
  {% end %}
end

# Errno wraps and gives access to libc's errno. This is mostly useful when
# dealing with C libraries.
#
# This class is the exception thrown when errno errors are encountered.
class Errno
  class Error < Exception
    # Returns the numeric value of errno.
    getter value : Int32

    # Returns the message of errno.
    getter errno_message : String

    # Creates a new `Errno` with the given message. The message will
    # have concatenated the errno message denoted by *errno*.
    #
    # Typical usage:
    #
    # ```
    # err = LibC.some_call
    # if err == -1
    #   raise Errno.new("some_call")
    # end
    # ```
    def initialize(message, @value = value)
      @errno_message = String.new(LibC.strerror(@value))
      super "#{message}: #{@errno_message}"
    end
    
    def self.value
      Errno.value
    end
  end

  # Argument list too long
  class E2BIG < Error
    class_getter value = LibC::E2BIG
  end

  # Operation not permitted
  class EPERM < Error
    class_getter value = LibC::EPERM
  end

  # No such file or directory
  class ENOENT < Error
    class_getter value = LibC::ENOENT
  end

  # No such process
  class ESRCH < Error
    class_getter value = LibC::ESRCH
  end

  # Interrupted system call
  class EINTR < Error
    class_getter value = LibC::EINTR
  end

  # Input/output error
  class EIO < Error
    class_getter value = LibC::EIO
  end

  # Device not configured
  class ENXIO < Error
    class_getter value = LibC::ENXIO
  end

  # Exec format error
  class ENOEXEC < Error
    class_getter value = LibC::ENOEXEC
  end

  # Bad file descriptor
  class EBADF < Error
    class_getter value = LibC::EBADF
  end

  # No child processes
  class ECHILD < Error
    class_getter value = LibC::ECHILD
  end

  # Resource deadlock avoided
  class EDEADLK < Error
    class_getter value = LibC::EDEADLK
  end

  # Cannot allocate memory
  class ENOMEM < Error
    class_getter value = LibC::ENOMEM
  end

  # Permission denied
  class EACCES < Error
    class_getter value = LibC::EACCES
  end

  # Bad address
  class EFAULT < Error
    class_getter value = LibC::EFAULT
  end

  # Block device required
  class ENOTBLK < Error
    class_getter value = LibC::ENOTBLK
  end

  # Device / Resource busy
  class EBUSY < Error
    class_getter value = LibC::EBUSY
  end

  # File exists
  class EEXIST < Error
    class_getter value = LibC::EEXIST
  end

  # Cross-device link
  class EXDEV < Error
    class_getter value = LibC::EXDEV
  end

  # Operation not supported by device
  class ENODEV < Error
    class_getter value = LibC::ENODEV
  end

  # Not a directory
  class ENOTDIR < Error
    class_getter value = LibC::ENOTDIR
  end

  # Is a directory
  class EISDIR < Error
    class_getter value = LibC::EISDIR
  end

  # Invalid argument
  class EINVAL < Error
    class_getter value = LibC::EINVAL
  end

  # Too many open files in system
  class ENFILE < Error
    class_getter value = LibC::ENFILE
  end

  # Too many open files
  class EMFILE < Error
    class_getter value = LibC::EMFILE
  end

  # Inappropriate ioctl for device
  class ENOTTY < Error
    class_getter value = LibC::ENOTTY
  end

  # Text file busy
  class ETXTBSY < Error
    class_getter value = LibC::ETXTBSY
  end

  # File too large
  class EFBIG < Error
    class_getter value = LibC::EFBIG
  end

  # No space left on device
  class ENOSPC < Error
    class_getter value = LibC::ENOSPC
  end

  # Illegal seek
  class ESPIPE < Error
    class_getter value = LibC::ESPIPE
  end

  # Read-only file system
  class EROFS < Error
    class_getter value = LibC::EROFS
  end

  # Too many links
  class EMLINK < Error
    class_getter value = LibC::EMLINK
  end

  # Broken pipe
  class EPIPE < Error
    class_getter value = LibC::EPIPE
  end

  # Numerical argument out of domain
  class EDOM < Error
    class_getter value = LibC::EDOM
  end

  # Result too large
  class ERANGE < Error
    class_getter value = LibC::ERANGE
  end

  # Resource temporarily unavailable
  class EAGAIN < Error
    class_getter value = LibC::EAGAIN
  end

  # Operation would block
  class EWOULDBLOCK < Error
    class_getter value = LibC::EWOULDBLOCK
  end

  # Operation now in progress
  class EINPROGRESS < Error
    class_getter value = LibC::EINPROGRESS
  end

  # Operation already in progress
  class EALREADY < Error
    class_getter value = LibC::EALREADY
  end

  # Socket operation on non-socket
  class ENOTSOCK < Error
    class_getter value = LibC::ENOTSOCK
  end

  # Destination address required
  class EDESTADDRREQ < Error
    class_getter value = LibC::EDESTADDRREQ
  end

  # Message too long
  class EMSGSIZE < Error
    class_getter value = LibC::EMSGSIZE
  end

  # Protocol wrong type for socket
  class EPROTOTYPE < Error
    class_getter value = LibC::EPROTOTYPE
  end

  # Protocol not available
  class ENOPROTOOPT < Error
    class_getter value = LibC::ENOPROTOOPT
  end

  # Protocol not supported
  class EPROTONOSUPPORT < Error
    class_getter value = LibC::EPROTONOSUPPORT
  end

  # Socket type not supported
  class ESOCKTNOSUPPORT < Error
    class_getter value = LibC::ESOCKTNOSUPPORT
  end

  # Protocol family not supported
  class EPFNOSUPPORT < Error
    class_getter value = LibC::EPFNOSUPPORT
  end

  # Address family not supported by protocol family
  class EAFNOSUPPORT < Error
    class_getter value = LibC::EAFNOSUPPORT
  end

  # Address already in use
  class EADDRINUSE < Error
    class_getter value = LibC::EADDRINUSE
  end

  # Can't assign requested address
  class EADDRNOTAVAIL < Error
    class_getter value = LibC::EADDRNOTAVAIL
  end

  # Network is down
  class ENETDOWN < Error
    class_getter value = LibC::ENETDOWN
  end

  # Network is unreachable
  class ENETUNREACH < Error
    class_getter value = LibC::ENETUNREACH
  end

  # Network dropped connection on reset
  class ENETRESET < Error
    class_getter value = LibC::ENETRESET
  end

  # Software caused connection abort
  class ECONNABORTED < Error
    class_getter value = LibC::ECONNABORTED
  end

  # Connection reset by peer
  class ECONNRESET < Error
    class_getter value = LibC::ECONNRESET
  end

  # No buffer space available
  class ENOBUFS < Error
    class_getter value = LibC::ENOBUFS
  end

  # Socket is already connected
  class EISCONN < Error
    class_getter value = LibC::EISCONN
  end

  # Socket is not connected
  class ENOTCONN < Error
    class_getter value = LibC::ENOTCONN
  end

  # Can't send after socket shutdown
  class ESHUTDOWN < Error
    class_getter value = LibC::ESHUTDOWN
  end

  # Too many references: can't splice
  class ETOOMANYREFS < Error
    class_getter value = LibC::ETOOMANYREFS
  end

  # Operation timed out
  class ETIMEDOUT < Error
    class_getter value = LibC::ETIMEDOUT
  end

  # Connection refused
  class ECONNREFUSED < Error
    class_getter value = LibC::ECONNREFUSED
  end

  # Too many levels of symbolic links
  class ELOOP < Error
    class_getter value = LibC::ELOOP
  end

  # File name too long
  class ENAMETOOLONG < Error
    class_getter value = LibC::ENAMETOOLONG
  end

  # Host is down
  class EHOSTDOWN < Error
    class_getter value = LibC::EHOSTDOWN
  end

  # No route to host
  class EHOSTUNREACH < Error
    class_getter value = LibC::EHOSTUNREACH
  end

  # Directory not empty
  class ENOTEMPTY < Error
    class_getter value = LibC::ENOTEMPTY
  end

  # Too many users
  class EUSERS < Error
    class_getter value = LibC::EUSERS
  end

  # Disc quota exceeded
  class EDQUOT < Error
    class_getter value = LibC::EDQUOT
  end

  # Stale NFS file handle
  class ESTALE < Error
    class_getter value = LibC::ESTALE
  end

  # Too many levels of remote in path
  class EREMOTE < Error
    class_getter value = LibC::EREMOTE
  end

  # No locks available
  class ENOLCK < Error
    class_getter value = LibC::ENOLCK
  end

  # Function not implemented
  class ENOSYS < Error
    class_getter value = LibC::ENOSYS
  end

  # Value too large to be stored in data type
  class EOVERFLOW < Error
    class_getter value = LibC::EOVERFLOW
  end

  # Operation canceled
  class ECANCELED < Error
    class_getter value = LibC::ECANCELED
  end

  # Identifier removed
  class EIDRM < Error
    class_getter value = LibC::EIDRM
  end

  # No message of desired type
  class ENOMSG < Error
    class_getter value = LibC::ENOMSG
  end

  # Illegal byte sequence
  class EILSEQ < Error
    class_getter value = LibC::EILSEQ
  end

  # Bad message
  class EBADMSG < Error
    class_getter value = LibC::EBADMSG
  end

  # Reserved
  class EMULTIHOP < Error
    class_getter value = LibC::EMULTIHOP
  end

  # No message available on STREAM
  class ENODATA < Error
    class_getter value = LibC::ENODATA
  end

  # Reserved
  class ENOLINK < Error
    class_getter value = LibC::ENOLINK
  end

  # No STREAM resources
  class ENOSR < Error
    class_getter value = LibC::ENOSR
  end

  # Not a STREAM
  class ENOSTR < Error
    class_getter value = LibC::ENOSTR
  end

  # Protocol error
  class EPROTO < Error
    class_getter value = LibC::EPROTO
  end

  # STREAM ioctl timeout
  class ETIME < Error
    class_getter value = LibC::ETIME
  end

  # Operation not supported on socket
  class EOPNOTSUPP < Error
    class_getter value = LibC::EOPNOTSUPP
  end

  # State not recoverable
  class ENOTRECOVERABLE < Error
    class_getter value = LibC::ENOTRECOVERABLE
  end

  # Previous owner died
  class EOWNERDEAD < Error
    class_getter value = LibC::EOWNERDEAD
  end
  
  def self.new(message, value = Errno.value)
    Error.new message, value
  end

  # Returns the value of libc's errno.
  def self.value : LibC::Int
    {% if flag?(:linux) %}
      LibC.__errno_location.value
    {% elsif flag?(:darwin) || flag?(:freebsd) || flag?(:openbsd) %}
      LibC.__error.value
    {% elsif flag?(:win32) %}
      ret = LibC._get_errno(out errno)
      raise Errno.new("_get_errno", ret) unless ret == 0
      errno
    {% end %}
  end

  # Sets the value of libc's errno.
  def self.value=(value)
    {% if flag?(:linux) %}
      LibC.__errno_location.value = value
    {% elsif flag?(:darwin) || flag?(:freebsd) || flag?(:openbsd) %}
      LibC.__error.value = value
    {% elsif flag?(:win32) %}
      ret = LibC._set_errno(value)
      raise Errno.new("_set_errno", ret) unless ret == 0
      value
    {% end %}
  end
end

