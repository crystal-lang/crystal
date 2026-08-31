require "c/errno"
require "c/string"

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
      {{ value.id }} = LibC::{{ value.id }}
    {% end %}
  {% end %}

  # Returns the system error message associated with this errno.
  #
  # NOTE: The result may depend on the current system locale. Specs and
  # comparisons should use `#value` instead of this method.
  def message : String
    unsafe_message { |slice| String.new(slice) }
  end

  # :nodoc:
  def unsafe_message(&)
    {% if LibC.has_method?(:strerror_r) %}
      buffer = uninitialized UInt8[256]
      if LibC.strerror_r(value, buffer, buffer.size) == 0
        yield Bytes.new(buffer.to_unsafe, LibC.strlen(buffer))
      else
        yield "(???)".to_slice
      end
    {% else %}
      pointer = LibC.strerror(value)
      yield Bytes.new(pointer, LibC.strlen(pointer))
    {% end %}
  end

  # returns the value of libc's errno.
  def self.value : self
    {% if LibC.has_method?(:__errno_location) %}
      Errno.new LibC.__errno_location.value
    {% elsif LibC.has_method?(:__errno) %}
      Errno.new LibC.__errno.value
    {% elsif LibC.has_method?(:__error) %}
      Errno.new LibC.__error.value
    {% elsif LibC.has_method?(:___errno) %}
      Errno.new LibC.___errno.value
    {% elsif flag?(:wasi) %}
      Errno.new LibC.errno
    {% elsif flag?(:win32) %}
      ret = LibC._get_errno(out errno)
      raise RuntimeError.from_os_error("_get_errno", Errno.new(ret)) unless ret == 0
      Errno.new errno
    {% else %}
      {% raise "ERROR: no errno definition for target" %}
    {% end %}
  end

  # Sets the value of libc's errno.
  def self.value=(errno : Errno)
    {% if LibC.has_method?(:__errno_location) %}
      LibC.__errno_location.value = errno.value
    {% elsif LibC.has_method?(:__errno) %}
      LibC.__errno.value = errno.value
    {% elsif LibC.has_method?(:__error) %}
      LibC.__error.value = errno.value
    {% elsif LibC.has_method?(:___errno) %}
      LibC.___errno.value = errno.value
    {% elsif flag?(:wasi) %}
      LibC.errno = errno.value
    {% elsif flag?(:win32) %}
      ret = LibC._set_errno(errno.value)
      raise RuntimeError.from_os_error("_set_errno", Errno.new(ret)) unless ret == 0
    {% else %}
      {% raise "ERROR: no errno definition for target" %}
    {% end %}
    errno
  end
end
