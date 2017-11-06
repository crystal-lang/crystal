require "c/fcntl"
require "io/syscall"

class Crystal::System::FileHandle
  include IO::Syscall

  @fd : Int32

  @read_event : Event::Event?
  @write_event : Event::Event?

  @closed = false

  def initialize(platform_specific : Int32)
    @fd = platform_specific
  end

  def platform_specific : Int32
    @fd
  end

  def read(slice : Bytes) : Int32
    read_syscall_helper(slice, "Error reading file") do
      # `to_i32` is acceptable because `Slice#size` is a Int32
      LibC.read(@fd, slice, slice.size).to_i32
    end
  end

  def write(slice : Bytes) : Nil
    write_syscall_helper(slice, "Error writing file") do |slice|
      LibC.write(@fd, slice, slice.size).tap do |return_code|
        if return_code == -1 && Errno.value == Errno::EBADF
          raise IO::Error.new "File not open for writing"
        end
      end
    end
  end

  def closed? : Bool
    @closed
  end

  def close : Nil
    return if @closed

    err = nil
    if LibC.close(@fd) != 0
      case Errno.value
      when Errno::EINTR, Errno::EINPROGRESS
        # ignore
      else
        err = Errno.new("Error closing file")
      end
    end

    @closed = true

    @read_event.try &.free
    @read_event = nil

    @write_event.try &.free
    @write_event = nil

    reschedule_waiting

    raise err if err
  end

  def blocking? : Bool
    (fcntl(LibC::F_GETFL) & LibC::O_NONBLOCK) == 0
  end

  def blocking=(value : Bool) : Bool
    flags = fcntl(LibC::F_GETFL)
    if value
      flags &= ~LibC::O_NONBLOCK
    else
      flags |= LibC::O_NONBLOCK
    end
    fcntl(LibC::F_SETFL, flags)

    value
  end

  def close_on_exec? : Bool
    (fcntl(LibC::F_GETFD) & LibC::FD_CLOEXEC) == LibC::FD_CLOEXEC
  end

  def close_on_exec=(value : Bool) : Bool
    flags = fcntl(LibC::F_GETFD)
    if value
      flags |= LibC::FD_CLOEXEC
    else
      flags &= ~LibC::FD_CLOEXEC
    end
    fcntl(LibC::F_SETFD, flags)

    value
  end

  def seek(offset : Number, whence : IO::Seek = IO::Seek::Set) : Int64
    check_open

    seek_value = LibC.lseek(@fd, offset.to_i64, whence)

    if seek_value == -1
      raise Errno.new "Unable to seek"
    end

    seek_value.to_i64
  end

  def tty? : Bool
    LibC.isatty(@fd) == 1
  end

  def reopen(other : FileHandle) : FileHandle
    {% if LibC.methods.includes? "dup3".id %}
      # dup doesn't copy the CLOEXEC flag, so copy it manually using dup3
      flags = other.close_on_exec? ? LibC::O_CLOEXEC : 0
      if LibC.dup3(other.platform_specific, self.platform_specific, flags) == -1
        raise Errno.new("Could not reopen file descriptor")
      end
    {% else %}
      # dup doesn't copy the CLOEXEC flag, copy it manually to the new
      if LibC.dup2(other.platform_specific, self.platform_specific) == -1
        raise Errno.new("Could not reopen file descriptor")
      end

      if other.close_on_exec?
        self.close_on_exec = true
      end
    {% end %}

    # We are now pointing to a new file descriptor, we need to re-register
    # events with libevent and enqueue readers and writers again.
    @read_event.try &.free
    @read_event = nil

    @write_event.try &.free
    @write_event = nil

    reschedule_waiting

    other
  end

  def stat : File::Stat
    if LibC.fstat(@fd, out stat) != 0
      raise Errno.new("Unable to get stat")
    end
    File::Stat.new(stat)
  end

  private def fcntl(cmd, arg = 0)
    LibC.fcntl(@fd, cmd, arg).tap do |ret|
      raise Errno.new("fcntl() failed") if ret == -1
    end
  end

  private def add_read_event(timeout = @read_timeout)
    event = @read_event ||= Scheduler.create_fd_read_event(self)
    event.add(timeout)
    nil
  end

  private def add_write_event(timeout = @write_timeout)
    event = @write_event ||= Scheduler.create_fd_write_event(self)
    event.add(timeout)
    nil
  end
end
