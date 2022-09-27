enum WasiError : UInt16
  # Returns the system error message associated with this error code.
  def message : String
    case self
    when SUCCESS        then "No error occurred. System call completed successfully."
    when TOOBIG         then "Argument list too long."
    when ACCES          then "Permission denied."
    when ADDRINUSE      then "Address in use."
    when ADDRNOTAVAIL   then "Address not available."
    when AFNOSUPPORT    then "Address family not supported."
    when AGAIN          then "Resource unavailable, or operation would block."
    when ALREADY        then "Connection already in progress."
    when BADF           then "Bad file descriptor."
    when BADMSG         then "Bad message."
    when BUSY           then "Device or resource busy."
    when CANCELED       then "Operation canceled."
    when CHILD          then "No child processes."
    when CONNABORTED    then "Connection aborted."
    when CONNREFUSED    then "Connection refused."
    when CONNRESET      then "Connection reset."
    when DEADLK         then "Resource deadlock would occur."
    when DESTADDRREQ    then "Destination address required."
    when DOM            then "Mathematics argument out of domain of function."
    when DQUOT          then "Reserved."
    when EXIST          then "File exists."
    when FAULT          then "Bad address."
    when FBIG           then "File too large."
    when HOSTUNREACH    then "Host is unreachable."
    when IDRM           then "Identifier removed."
    when ILSEQ          then "Illegal byte sequence."
    when INPROGRESS     then "Operation in progress."
    when INTR           then "Interrupted function."
    when INVAL          then "Invalid argument."
    when IO             then "I/O error."
    when ISCONN         then "Socket is connected."
    when ISDIR          then "Is a directory."
    when LOOP           then "Too many levels of symbolic links."
    when MFILE          then "File descriptor value too large."
    when MLINK          then "Too many links."
    when MSGSIZE        then "Message too large."
    when MULTIHOP       then "Reserved."
    when NAMETOOLONG    then "Filename too long."
    when NETDOWN        then "Network is down."
    when NETRESET       then "Connection aborted by network."
    when NETUNREACH     then "Network unreachable."
    when NFILE          then "Too many files open in system."
    when NOBUFS         then "No buffer space available."
    when NODEV          then "No such device."
    when NOENT          then "No such file or directory."
    when NOEXEC         then "Executable file format error."
    when NOLCK          then "No locks available."
    when NOLINK         then "Reserved."
    when NOMEM          then "Not enough space."
    when NOMSG          then "No message of the desired type."
    when NOPROTOOPT     then "Protocol not available."
    when NOSPC          then "No space left on device."
    when NOSYS          then "Function not supported."
    when NOTCONN        then "The socket is not connected."
    when NOTDIR         then "Not a directory or a symbolic link to a directory."
    when NOTEMPTY       then "Directory not empty."
    when NOTRECOVERABLE then "State not recoverable."
    when NOTSOCK        then "Not a socket."
    when NOTSUP         then "Not supported, or operation not supported on socket."
    when NOTTY          then "Inappropriate I/O control operation."
    when NXIO           then "No such device or address."
    when OVERFLOW       then "Value too large to be stored in data type."
    when OWNERDEAD      then "Previous owner died."
    when PERM           then "Operation not permitted."
    when PIPE           then "Broken pipe."
    when PROTO          then "Protocol error."
    when PROTONOSUPPORT then "Protocol not supported."
    when PROTOTYPE      then "Protocol wrong type for socket."
    when RANGE          then "Result too large."
    when ROFS           then "Read-only file system."
    when SPIPE          then "Invalid seek."
    when SRCH           then "No such process."
    when STALE          then "Reserved."
    when TIMEDOUT       then "Connection timed out."
    when TXTBSY         then "Text file busy."
    when XDEV           then "Cross-device link."
    when NOTCAPABLE     then "Extension: Capabilities insufficient."
    else                     "Unknown error."
    end
  end

  # Transforms this `WasiError` value to the equivalent `Errno` value.
  #
  # This is only defined for some values. If no transformation is defined for
  # a specific value, the default result is `Errno::EINVAL`.
  def to_errno : Errno
    case self
    when TOOBIG         then Errno::E2BIG
    when ACCES          then Errno::EACCES
    when ADDRINUSE      then Errno::EADDRINUSE
    when ADDRNOTAVAIL   then Errno::EADDRNOTAVAIL
    when AFNOSUPPORT    then Errno::EAFNOSUPPORT
    when AGAIN          then Errno::EAGAIN
    when ALREADY        then Errno::EALREADY
    when BADF           then Errno::EBADF
    when BADMSG         then Errno::EBADMSG
    when BUSY           then Errno::EBUSY
    when CANCELED       then Errno::ECANCELED
    when CHILD          then Errno::ECHILD
    when CONNABORTED    then Errno::ECONNABORTED
    when CONNREFUSED    then Errno::ECONNREFUSED
    when CONNRESET      then Errno::ECONNRESET
    when DEADLK         then Errno::EDEADLK
    when DESTADDRREQ    then Errno::EDESTADDRREQ
    when DOM            then Errno::EDOM
    when DQUOT          then Errno::EDQUOT
    when EXIST          then Errno::EEXIST
    when FAULT          then Errno::EFAULT
    when FBIG           then Errno::EFBIG
    when HOSTUNREACH    then Errno::EHOSTUNREACH
    when IDRM           then Errno::EIDRM
    when ILSEQ          then Errno::EILSEQ
    when INPROGRESS     then Errno::EINPROGRESS
    when INTR           then Errno::EINTR
    when INVAL          then Errno::EINVAL
    when IO             then Errno::EIO
    when ISCONN         then Errno::EISCONN
    when ISDIR          then Errno::EISDIR
    when LOOP           then Errno::ELOOP
    when MFILE          then Errno::EMFILE
    when MLINK          then Errno::EMLINK
    when MSGSIZE        then Errno::EMSGSIZE
    when MULTIHOP       then Errno::EMULTIHOP
    when NAMETOOLONG    then Errno::ENAMETOOLONG
    when NETDOWN        then Errno::ENETDOWN
    when NETRESET       then Errno::ENETRESET
    when NETUNREACH     then Errno::ENETUNREACH
    when NFILE          then Errno::ENFILE
    when NOBUFS         then Errno::ENOBUFS
    when NODEV          then Errno::ENODEV
    when NOENT          then Errno::ENOENT
    when NOEXEC         then Errno::ENOEXEC
    when NOLCK          then Errno::ENOLCK
    when NOLINK         then Errno::ENOLINK
    when NOMEM          then Errno::ENOMEM
    when NOMSG          then Errno::ENOMSG
    when NOPROTOOPT     then Errno::ENOPROTOOPT
    when NOSPC          then Errno::ENOSPC
    when NOSYS          then Errno::ENOSYS
    when NOTCONN        then Errno::ENOTCONN
    when NOTDIR         then Errno::ENOTDIR
    when NOTEMPTY       then Errno::ENOTEMPTY
    when NOTRECOVERABLE then Errno::ENOTRECOVERABLE
    when NOTSOCK        then Errno::ENOTSOCK
    when NOTSUP         then Errno::ENOTSUP
    when NOTTY          then Errno::ENOTTY
    when NXIO           then Errno::ENXIO
    when OVERFLOW       then Errno::EOVERFLOW
    when OWNERDEAD      then Errno::EOWNERDEAD
    when PERM           then Errno::EPERM
    when PIPE           then Errno::EPIPE
    when PROTO          then Errno::EPROTO
    when PROTONOSUPPORT then Errno::EPROTONOSUPPORT
    when PROTOTYPE      then Errno::EPROTOTYPE
    when RANGE          then Errno::ERANGE
    when ROFS           then Errno::EROFS
    when SPIPE          then Errno::ESPIPE
    when SRCH           then Errno::ESRCH
    when STALE          then Errno::ESTALE
    when TIMEDOUT       then Errno::ETIMEDOUT
    when TXTBSY         then Errno::ETXTBSY
    when XDEV           then Errno::EXDEV
    when NOTCAPABLE     then Errno::ENOTCAPABLE
    else                     Errno::EINVAL
    end
  end

  SUCCESS        # No error occurred. System call completed successfully.
  TOOBIG         # Argument list too long.
  ACCES          # Permission denied.
  ADDRINUSE      # Address in use.
  ADDRNOTAVAIL   # Address not available.
  AFNOSUPPORT    # Address family not supported.
  AGAIN          # Resource unavailable, or operation would block.
  ALREADY        # Connection already in progress.
  BADF           # Bad file descriptor.
  BADMSG         # Bad message.
  BUSY           # Device or resource busy.
  CANCELED       # Operation canceled.
  CHILD          # No child processes.
  CONNABORTED    # Connection aborted.
  CONNREFUSED    # Connection refused.
  CONNRESET      # Connection reset.
  DEADLK         # Resource deadlock would occur.
  DESTADDRREQ    # Destination address required.
  DOM            # Mathematics argument out of domain of function.
  DQUOT          # Reserved.
  EXIST          # File exists.
  FAULT          # Bad address.
  FBIG           # File too large.
  HOSTUNREACH    # Host is unreachable.
  IDRM           # Identifier removed.
  ILSEQ          # Illegal byte sequence.
  INPROGRESS     # Operation in progress.
  INTR           # Interrupted function.
  INVAL          # Invalid argument.
  IO             # I/O error.
  ISCONN         # Socket is connected.
  ISDIR          # Is a directory.
  LOOP           # Too many levels of symbolic links.
  MFILE          # File descriptor value too large.
  MLINK          # Too many links.
  MSGSIZE        # Message too large.
  MULTIHOP       # Reserved.
  NAMETOOLONG    # Filename too long.
  NETDOWN        # Network is down.
  NETRESET       # Connection aborted by network.
  NETUNREACH     # Network unreachable.
  NFILE          # Too many files open in system.
  NOBUFS         # No buffer space available.
  NODEV          # No such device.
  NOENT          # No such file or directory.
  NOEXEC         # Executable file format error.
  NOLCK          # No locks available.
  NOLINK         # Reserved.
  NOMEM          # Not enough space.
  NOMSG          # No message of the desired type.
  NOPROTOOPT     # Protocol not available.
  NOSPC          # No space left on device.
  NOSYS          # Function not supported.
  NOTCONN        # The socket is not connected.
  NOTDIR         # Not a directory or a symbolic link to a directory.
  NOTEMPTY       # Directory not empty.
  NOTRECOVERABLE # State not recoverable.
  NOTSOCK        # Not a socket.
  NOTSUP         # Not supported, or operation not supported on socket.
  NOTTY          # Inappropriate I/O control operation.
  NXIO           # No such device or address.
  OVERFLOW       # Value too large to be stored in data type.
  OWNERDEAD      # Previous owner died.
  PERM           # Operation not permitted.
  PIPE           # Broken pipe.
  PROTO          # Protocol error.
  PROTONOSUPPORT # Protocol not supported.
  PROTOTYPE      # Protocol wrong type for socket.
  RANGE          # Result too large.
  ROFS           # Read-only file system.
  SPIPE          # Invalid seek.
  SRCH           # No such process.
  STALE          # Reserved.
  TIMEDOUT       # Connection timed out.
  TXTBSY         # Text file busy.
  XDEV           # Cross-device link.
  NOTCAPABLE     # Extension: Capabilities insufficient.
end
