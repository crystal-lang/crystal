require "c/fcntl"
require "termios"
{% if flag?(:android) && LibC::ANDROID_API < 28 %}
  require "c/sys/ioctl"
{% end %}

# :nodoc:
module Crystal::System::FileDescriptor
  {% if IO.has_constant?(:Evented) %}
    include IO::Evented
  {% end %}

  # Platform-specific type to represent a file descriptor handle to the operating
  # system.
  alias Handle = Int32

  STDIN_HANDLE  = 0
  STDOUT_HANDLE = 1
  STDERR_HANDLE = 2

  private def system_blocking?
    flags = fcntl(LibC::F_GETFL)
    !flags.bits_set? LibC::O_NONBLOCK
  end

  private def system_blocking=(value)
    current_flags = fcntl(LibC::F_GETFL)
    new_flags = current_flags
    if value
      new_flags &= ~LibC::O_NONBLOCK
    else
      new_flags |= LibC::O_NONBLOCK
    end
    fcntl(LibC::F_SETFL, new_flags) unless new_flags == current_flags
  end

  private def system_blocking_init(value)
    self.system_blocking = false unless value
  end

  private def system_close_on_exec?
    flags = fcntl(LibC::F_GETFD)
    flags.bits_set? LibC::FD_CLOEXEC
  end

  private def system_close_on_exec=(arg : Bool)
    fcntl(LibC::F_SETFD, arg ? LibC::FD_CLOEXEC : 0)
    arg
  end

  private def system_closed?
    LibC.fcntl(fd, LibC::F_GETFL) == -1
  end

  def self.fcntl(fd, cmd, arg = 0)
    r = LibC.fcntl(fd, cmd, arg)
    raise IO::Error.from_errno("fcntl() failed") if r == -1
    r
  end

  def self.system_info(fd)
    stat = uninitialized LibC::Stat
    ret = File.fstat(fd, pointerof(stat))

    if ret != 0
      raise IO::Error.from_errno("Unable to get info")
    end

    ::File::Info.new(stat)
  end

  private def system_info
    FileDescriptor.system_info fd
  end

  private def system_seek(offset, whence : IO::Seek) : Nil
    seek_value = LibC.lseek(fd, offset, whence)

    if seek_value == -1
      raise IO::Error.from_errno "Unable to seek", target: self
    end
  end

  private def system_pos
    pos = LibC.lseek(fd, 0, IO::Seek::Current).to_i64
    raise IO::Error.from_errno("Unable to tell", target: self) if pos == -1
    pos
  end

  private def system_tty?
    LibC.isatty(fd) == 1
  end

  private def system_reopen(other : IO::FileDescriptor)
    {% if LibC.has_method?(:dup3) %}
      flags = other.close_on_exec? ? LibC::O_CLOEXEC : 0
      if LibC.dup3(other.fd, fd, flags) == -1
        raise IO::Error.from_errno("Could not reopen file descriptor")
      end
    {% else %}
      Process.lock_read do
        if LibC.dup2(other.fd, fd) == -1
          raise IO::Error.from_errno("Could not reopen file descriptor")
        end
        self.close_on_exec = other.close_on_exec?
      end
    {% end %}

    # Mark the handle open, since we had to have dup'd a live handle.
    @closed = false

    event_loop.close(self)
  end

  private def system_close
    # Perform libevent cleanup before LibC.close.
    # Using a file descriptor after it has been closed is never defined and can
    # always lead to undefined results. This is not specific to libevent.
    event_loop.close(self)

    file_descriptor_close
  end

  def file_descriptor_close(&) : Nil
    # It would usually be set by IO::Buffered#unbuffered_close but we sometimes
    # close file descriptors directly (i.e. signal/process pipes) and the IO
    # object wouldn't be marked as closed, leading IO::FileDescriptor#finalize
    # to try to close the fd again (pointless) and lead to other issues if we
    # try to do more cleanup in the finalizer (error)
    @closed = true

    # Clear the @volatile_fd before actually closing it in order to
    # reduce the chance of reading an outdated fd value
    _fd = @volatile_fd.swap(-1)

    if LibC.close(_fd) != 0
      case Errno.value
      when Errno::EINTR, Errno::EINPROGRESS
        # ignore
      else
        yield
      end
    end
  end

  def file_descriptor_close
    file_descriptor_close do
      raise IO::Error.from_errno("Error closing file", target: self)
    end
  end

  private def system_flock_shared(blocking)
    flock LibC::FlockOp::SH, blocking
  end

  private def system_flock_exclusive(blocking)
    flock LibC::FlockOp::EX, blocking
  end

  private def system_flock_unlock
    flock LibC::FlockOp::UN
  end

  private def flock(op : LibC::FlockOp, retry : Bool) : Nil
    op |= LibC::FlockOp::NB

    if retry
      until flock(op)
        sleep 0.1.seconds
      end
    else
      flock(op) || raise IO::Error.from_errno("Error applying file lock: file is already locked", target: self)
    end
  end

  private def flock(op) : Bool
    if 0 == LibC.flock(fd, op)
      true
    else
      errno = Errno.value
      if errno.in?(Errno::EAGAIN, Errno::EWOULDBLOCK)
        false
      else
        raise IO::Error.from_os_error("Error applying or removing file lock", errno, target: self)
      end
    end
  end

  private def system_fsync(flush_metadata = true) : Nil
    ret =
      if flush_metadata
        LibC.fsync(fd)
      else
        {% if flag?(:dragonfly) %}
          LibC.fsync(fd)
        {% else %}
          LibC.fdatasync(fd)
        {% end %}
      end

    if ret != 0
      raise IO::Error.from_errno("Error syncing file", target: self)
    end
  end

  def self.pipe(read_blocking, write_blocking)
    pipe_fds = system_pipe
    r = IO::FileDescriptor.new(pipe_fds[0], read_blocking)
    w = IO::FileDescriptor.new(pipe_fds[1], write_blocking)
    w.sync = true
    {r, w}
  end

  def self.system_pipe : StaticArray(LibC::Int, 2)
    pipe_fds = uninitialized StaticArray(LibC::Int, 2)

    {% if LibC.has_method?(:pipe2) %}
      if LibC.pipe2(pipe_fds, LibC::O_CLOEXEC) != 0
        raise IO::Error.from_errno("Could not create pipe")
      end
    {% else %}
      Process.lock_read do
        if LibC.pipe(pipe_fds) != 0
          raise IO::Error.from_errno("Could not create pipe")
        end
        fcntl(pipe_fds[0], LibC::F_SETFD, LibC::FD_CLOEXEC)
        fcntl(pipe_fds[1], LibC::F_SETFD, LibC::FD_CLOEXEC)
      end
    {% end %}

    pipe_fds
  end

  def self.pread(file, buffer, offset)
    bytes_read = LibC.pread(file.fd, buffer, buffer.size, offset).to_i64

    if bytes_read == -1
      raise IO::Error.from_errno("Error reading file", target: file)
    end

    bytes_read
  end

  def self.from_stdio(fd)
    # If we have a TTY for stdin/out/err, it is possibly a shared terminal.
    # We need to reopen it to use O_NONBLOCK without causing other programs to break

    # Figure out the terminal TTY name. If ttyname fails we have a non-tty, or something strange.
    # For non-tty we set flush_on_newline to true for reasons described in STDOUT and STDERR docs.
    path = uninitialized UInt8[256]
    ret = LibC.ttyname_r(fd, path, 256)
    return IO::FileDescriptor.new(fd).tap(&.flush_on_newline=(true)) unless ret == 0

    clone_fd = LibC.open(path, LibC::O_RDWR | LibC::O_CLOEXEC)
    return IO::FileDescriptor.new(fd).tap(&.flush_on_newline=(true)) if clone_fd == -1

    # We don't buffer output for TTY devices to see their output right away
    io = IO::FileDescriptor.new(clone_fd)
    io.sync = true
    io
  end

  # Helper to write *size* values at *pointer* to a given *fd*.
  def self.write_fully(fd : LibC::Int, pointer : Pointer, size : Int32 = 1) : Nil
    write_fully(fd, Slice.new(pointer, size).unsafe_slice_of(UInt8))
  end

  # Helper to fully write a slice to a given *fd*.
  def self.write_fully(fd : LibC::Int, slice : Slice(UInt8)) : Nil
    until slice.size == 0
      size = LibC.write(fd, slice, slice.size)
      break if size == -1
      slice += size
    end
  end

  private def system_echo(enable : Bool, mode = nil)
    new_mode = mode || FileDescriptor.tcgetattr(fd)
    flags = LibC::ECHO | LibC::ECHOE | LibC::ECHOK | LibC::ECHONL
    new_mode.c_lflag = enable ? (new_mode.c_lflag | flags) : (new_mode.c_lflag & ~flags)
    if FileDescriptor.tcsetattr(fd, LibC::TCSANOW, pointerof(new_mode)) != 0
      raise IO::Error.from_errno("tcsetattr")
    end
  end

  private def system_echo(enable : Bool, & : ->)
    system_console_mode do |mode|
      system_echo(enable, mode)
      yield
    end
  end

  private def system_raw(enable : Bool, mode = nil)
    new_mode = mode || FileDescriptor.tcgetattr(fd)
    if enable
      new_mode = FileDescriptor.cfmakeraw(new_mode)
    else
      new_mode.c_iflag |= LibC::BRKINT | LibC::ISTRIP | LibC::ICRNL | LibC::IXON
      new_mode.c_oflag |= LibC::OPOST
      new_mode.c_lflag |= LibC::ECHO | LibC::ECHOE | LibC::ECHOK | LibC::ECHONL | LibC::ICANON | LibC::ISIG | LibC::IEXTEN
    end
    if FileDescriptor.tcsetattr(fd, LibC::TCSANOW, pointerof(new_mode)) != 0
      raise IO::Error.from_errno("tcsetattr")
    end
  end

  private def system_raw(enable : Bool, & : ->)
    system_console_mode do |mode|
      system_raw(enable, mode)
      yield
    end
  end

  @[AlwaysInline]
  private def system_console_mode(&)
    before = FileDescriptor.tcgetattr(fd)
    begin
      yield before
    ensure
      FileDescriptor.tcsetattr(fd, LibC::TCSANOW, pointerof(before))
    end
  end

  @[AlwaysInline]
  def self.tcgetattr(fd)
    termios = uninitialized LibC::Termios
    {% if LibC.has_method?(:tcgetattr) %}
      ret = LibC.tcgetattr(fd, pointerof(termios))
      raise IO::Error.from_errno("tcgetattr") if ret == -1
    {% else %}
      ret = LibC.ioctl(fd, LibC::TCGETS, pointerof(termios))
      raise IO::Error.from_errno("ioctl") if ret == -1
    {% end %}
    termios
  end

  @[AlwaysInline]
  def self.tcsetattr(fd, optional_actions, termios_p)
    {% if LibC.has_method?(:tcsetattr) %}
      LibC.tcsetattr(fd, optional_actions, termios_p)
    {% else %}
      optional_actions = optional_actions.value if optional_actions.is_a?(Termios::LineControl)
      cmd = case optional_actions
            when LibC::TCSANOW
              LibC::TCSETS
            when LibC::TCSADRAIN
              LibC::TCSETSW
            when LibC::TCSAFLUSH
              LibC::TCSETSF
            else
              Errno.value = Errno::EINVAL
              return LibC::Int.new(-1)
            end

      LibC.ioctl(fd, cmd, termios_p)
    {% end %}
  end

  @[AlwaysInline]
  def self.cfmakeraw(termios)
    {% if LibC.has_method?(:cfmakeraw) %}
      LibC.cfmakeraw(pointerof(termios))
    {% else %}
      termios.c_iflag &= ~(LibC::IGNBRK | LibC::BRKINT | LibC::PARMRK | LibC::ISTRIP | LibC::INLCR | LibC::IGNCR | LibC::ICRNL | LibC::IXON)
      termios.c_oflag &= ~LibC::OPOST
      termios.c_lflag &= ~(LibC::ECHO | LibC::ECHONL | LibC::ICANON | LibC::ISIG | LibC::IEXTEN)
      termios.c_cflag &= ~(LibC::CSIZE | LibC::PARENB)
      termios.c_cflag |= LibC::CS8
      termios.c_cc[LibC::VMIN] = 1
      termios.c_cc[LibC::VTIME] = 0
    {% end %}
    termios
  end
end
