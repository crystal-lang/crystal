# An IO over a file descriptor.
class IO::FileDescriptor
  include Buffered

  private getter! readers
  private getter! writers

  # :nodoc:
  property read_timed_out, write_timed_out # only used in event callbacks

  def initialize(fd, blocking = false, edge_triggerable = false)
    @edge_triggerable = !!edge_triggerable
    @flush_on_newline = false
    @sync = false
    @closed = false
    @read_timed_out = false
    @write_timed_out = false
    @fd = fd
    @in_buffer_rem = Slice.new(Pointer(UInt8).null, 0)
    @out_count = 0
    @read_timeout = nil
    @write_timeout = nil
    @readers = [] of Fiber
    @writers = [] of Fiber

    unless blocking
      self.blocking = false
      if @edge_triggerable
        @read_event = Scheduler.create_fd_read_event(self, @edge_triggerable)
        @write_event = Scheduler.create_fd_write_event(self, @edge_triggerable)
      end
    end
  end

  # Set the number of seconds to wait when reading before raising an `IO::Timeout`.
  def read_timeout=(read_timeout : Number)
    @read_timeout = read_timeout.to_f
  end

  # ditto
  def read_timeout=(read_timeout : Time::Span)
    self.read_timeout = read_timeout.total_seconds
  end

  # Sets no timeout on read operations, so an `IO::Timeout` will never be raised.
  def read_timeout=(read_timeout : Nil)
    @read_timeout = nil
  end

  # Set the number of seconds to wait when writing before raising an `IO::Timeout`.
  def write_timeout=(write_timeout : Number)
    @write_timeout = write_timeout.to_f
  end

  # ditto
  def write_timeout=(write_timeout : Time::Span)
    self.write_timeout = write_timeout.total_seconds
  end

  # Sets no timeout on write operations, so an `IO::Timeout` will never be raised.
  def write_timeout=(write_timeout : Nil)
    @write_timeout = nil
  end

  def blocking
    fcntl(LibC::FCNTL::F_GETFL) & LibC::O_NONBLOCK == 0
  end

  def blocking=(value)
    flags = fcntl(LibC::FCNTL::F_GETFL)
    if value
      flags &= ~LibC::O_NONBLOCK
    else
      flags |= LibC::O_NONBLOCK
    end
    fcntl(LibC::FCNTL::F_SETFL, flags)
  end

  def close_on_exec?
    flags = fcntl(LibC::FCNTL::F_GETFD)
    (flags & LibC::FD_CLOEXEC) == LibC::FD_CLOEXEC
  end

  def close_on_exec=(arg : Bool)
    fcntl(LibC::FCNTL::F_SETFD, arg ? LibC::FD_CLOEXEC : 0)
    arg
  end

  def self.fcntl(fd, cmd, arg = 0)
    r = LibC.fcntl fd, cmd, arg
    raise Errno.new("fcntl() failed") if r == -1
    r
  end

  def fcntl(cmd, arg = 0)
    self.class.fcntl @fd, cmd, arg
  end

  # :nodoc:
  def resume_read
    if reader = readers.pop?
      reader.resume
    end
  end

  # :nodoc:
  def resume_write
    if writer = writers.pop?
      writer.resume
    end
  end

  def stat
    if LibC.fstat(@fd, out stat) != 0
      raise Errno.new("Unable to get stat")
    end
    File::Stat.new(stat)
  end

  def fd
    @fd
  end

  def finalize
    return if closed?

    close rescue nil
  end

  def closed?
    @closed
  end

  def tty?
    LibC.isatty(fd) == 1
  end

  def reopen(other : IO::FileDescriptor)
    if LibC.dup2(other.fd, self.fd) == -1
      raise Errno.new("Could not reopen file descriptor")
    end

    # flag is lost after dup
    self.close_on_exec = true

    other
  end

  def to_fd_io
    self
  end

  private def unbuffered_read(slice : Slice(UInt8))
    count = slice.size
    loop do
      bytes_read = LibC.read(@fd, slice.pointer(count), count)
      if bytes_read != -1
        return bytes_read
      end

      if LibC.errno == Errno::EAGAIN
        wait_readable
      else
        raise Errno.new "Error reading file"
      end
    end
  ensure
    add_read_event unless readers.empty?
  end

  private def unbuffered_write(slice : Slice(UInt8))
    count = slice.size
    total = count
    loop do
      bytes_written = LibC.write(@fd, slice.pointer(count), count)
      if bytes_written != -1
        count -= bytes_written
        return total if count == 0
        slice += bytes_written
      else
        if LibC.errno == Errno::EAGAIN
          wait_writable
          next
        elsif LibC.errno == Errno::EBADF
          raise IO::Error.new "File not open for writing"
        else
          raise Errno.new "Error writing file"
        end
      end
    end
  ensure
    add_write_event unless writers.empty?
  end

  private def wait_readable
    wait_readable { |err| raise err }
  end

  private def wait_readable
    readers << Fiber.current
    add_read_event
    Scheduler.reschedule

    if @read_timed_out
      @read_timed_out = false
      yield Timeout.new("read timed out")
    end

    nil
  end

  private def add_read_event
    return if @edge_triggerable
    event = @read_event ||= Scheduler.create_fd_read_event(self)
    event.add @read_timeout
    nil
  end

  private def wait_writable(timeout = @write_timeout)
    wait_writable(timeout: timeout) { |err| raise err }
  end

  # msg/timeout are overridden in nonblock_connect
  private def wait_writable(msg = "write timed out", timeout = @write_timeout)
    writers << Fiber.current
    add_write_event timeout
    Scheduler.reschedule

    if @write_timed_out
      @write_timed_out = false
      yield Timeout.new(msg)
    end

    nil
  end

  private def add_write_event(timeout = @write_timeout)
    return if @edge_triggerable
    event = @write_event ||= Scheduler.create_fd_write_event(self)
    event.add timeout
    nil
  end

  private def unbuffered_rewind
    seek(0, IO::Seek::Set)
    self
  end

  private def unbuffered_close
    return if @closed

    err = nil
    if LibC.close(@fd) != 0
      case LibC.errno
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
    Scheduler.enqueue @readers
    @readers.clear
    Scheduler.enqueue @writers
    @writers.clear

    raise err if err
  end

  private def unbuffered_flush
    # Nothing
  end

  private def check_open
    if closed?
      raise IO::Error.new "closed stream"
    end
  end
end
