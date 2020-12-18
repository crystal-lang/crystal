require "c/errno"
require "c/string"

lib LibC
  {% if flag?(:linux) || flag?(:dragonfly) %}
    fun __errno_location : Int*
  {% elsif flag?(:darwin) || flag?(:freebsd) %}
    fun __error : Int*
  {% elsif flag?(:netbsd) || flag?(:openbsd) %}
    fun __error = __errno : Int*
  {% elsif flag?(:win32) %}
    fun _get_errno(value : Int*) : ErrnoT
    fun _set_errno(value : Int) : ErrnoT
  {% end %}
end

# Errno wraps and gives access to libc's errno. This is mostly useful when
# dealing with C libraries.
enum Errno
  NONE = 0

  {% for value in %w(E2BIG EPERM ENOENT ESRCH EINTR EIO ENXIO ENOEXEC EBADF ECHILD EDEADLK ENOMEM
                    EACCES EFAULT ENOTBLK EBUSY EEXIST EXDEV ENODEV ENOTDIR EISDIR EINVAL ENFILE
                    EMFILE ENOTTY ETXTBSY EFBIG ENOSPC ESPIPE EROFS EMLINK EPIPE EDOM ERANGE EAGAIN
                    EWOULDBLOCK EINPROGRESS EALREADY ENOTSOCK EDESTADDRREQ EMSGSIZE EPROTOTYPE ENOPROTOOPT
                    EPROTONOSUPPORT ESOCKTNOSUPPORT EPFNOSUPPORT EAFNOSUPPORT EADDRINUSE EADDRNOTAVAIL
                    ENETDOWN ENETUNREACH ENETRESET ECONNABORTED ECONNRESET ENOBUFS EISCONN ENOTCONN
                    ESHUTDOWN ETOOMANYREFS ETIMEDOUT ECONNREFUSED ELOOP ENAMETOOLONG EHOSTDOWN
                    EHOSTUNREACH ENOTEMPTY EUSERS EDQUOT ESTALE EREMOTE ENOLCK ENOSYS EOVERFLOW
                    ECANCELED EIDRM ENOMSG EILSEQ EBADMSG EMULTIHOP ENODATA ENOLINK ENOSR ENOSTR
                    EPROTO ETIME EOPNOTSUPP ENOTRECOVERABLE EOWNERDEAD) %}
    {% if LibC.has_constant?(value) %}
      {{value.id}} = LibC::{{value.id}}
    {% end %}
  {% end %}

  # Convert an Errno to an error message
  def message : String
    String.new(LibC.strerror(value))
  end

  # Returns the value of libc's errno.
  def self.value : self
    {% if flag?(:linux) || flag?(:dragonfly) %}
      Errno.new LibC.__errno_location.value
    {% elsif flag?(:darwin) || flag?(:bsd) %}
      Errno.new LibC.__error.value
    {% elsif flag?(:win32) %}
      ret = LibC._get_errno(out errno)
      raise RuntimeError.from_errno("_get_errno", Errno.new(ret)) unless ret == 0
      Errno.new errno
    {% end %}
  end

  # Sets the value of libc's errno.
  def self.value=(errno : Errno)
    {% if flag?(:linux) || flag?(:dragonfly) %}
      LibC.__errno_location.value = errno.value
    {% elsif flag?(:darwin) || flag?(:bsd) %}
      LibC.__error.value = errno.value
    {% elsif flag?(:win32) %}
      ret = LibC._set_errno(errno.value)
      raise RuntimeError.from_errno("_set_errno", ret) unless ret == 0
    {% end %}
    errno
  end
end
