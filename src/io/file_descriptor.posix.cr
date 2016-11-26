require "c/fcntl"

# An IO over a file descriptor.
class IO::FileDescriptor
  include Buffered

  @read_timeout : Float64?
  @write_timeout : Float64?
  @read_event : Event::Event?
  @write_event : Event::Event?

  # :nodoc:
  property read_timed_out : Bool
  property write_timed_out : Bool

  def initialize(@fd : Int32, blocking = false, edge_triggerable = false)
    @edge_triggerable = !!edge_triggerable
    @closed = false
    @read_timed_out = false
    @write_timed_out = false
    @fd = fd

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
    fcntl(LibC::F_GETFL) & LibC::O_NONBLOCK == 0
  end

  def blocking=(value)
    flags = fcntl(LibC::F_GETFL)
    if value
      flags &= ~LibC::O_NONBLOCK
    else
      flags |= LibC::O_NONBLOCK
    end
    fcntl(LibC::F_SETFL, flags)
  end

  def close_on_exec?
    flags = fcntl(LibC::F_GETFD)
    (flags & LibC::FD_CLOEXEC) == LibC::FD_CLOEXEC
  end

  def close_on_exec=(arg : Bool)
    fcntl(LibC::F_SETFD, arg ? LibC::FD_CLOEXEC : 0)
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
    if reader = @readers.try &.shift?
      reader.resume
    end
  end

  # :nodoc:
  def resume_write
    if writer = @writers.try &.shift?
      writer.resume
    end
  end

  def stat
    if LibC.fstat(@fd, out stat) != 0
      raise Errno.new("Unable to get stat")
    end
    File::Stat.new(stat)
  end

  # Seeks to a given *offset* (in bytes) according to the *whence* argument.
  # Returns `self`.
  #
  # ```
  # file = File.new("testfile")
  # file.gets(3) # => "abc"
  # file.seek(1, IO::Seek::Set)
  # file.gets(2) # => "bc"
  # file.seek(-1, IO::Seek::Current)
  # file.gets(1) # => "c"
  # ```
  def seek(offset, whence : Seek = Seek::Set)
    check_open

    flush
    seek_value = LibC.lseek(@fd, offset, whence)
    if seek_value == -1
      raise Errno.new "Unable to seek"
    end

    @in_buffer_rem = Slice.new(Pointer(UInt8).null, 0)

    self
  end

  # Same as `seek` but yields to the block after seeking and eventually seeks
  # back to the original position when the block returns.
  def seek(offset, whence : Seek = Seek::Set)
    original_pos = tell
    begin
      seek(offset, whence)
      yield
    ensure
      seek(original_pos)
    end
  end

  # Same as `pos`.
  def tell
    pos
  end

  # Returns the current position (in bytes) in this IO.
  #
  # ```
  # io = IO::Memory.new "hello"
  # io.pos     # => 0
  # io.gets(2) # => "he"
  # io.pos     # => 2
  # ```
  def pos
    check_open

    seek_value = LibC.lseek(@fd, 0, Seek::Current)
    raise Errno.new "Unable to tell" if seek_value == -1

    seek_value - @in_buffer_rem.size
  end

  # Sets the current position (in bytes) in this IO.
  #
  # ```
  # io = IO::Memory.new "hello"
  # io.pos = 3
  # io.gets_to_end # => "lo"
  # ```
  def pos=(value)
    seek value
    value
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

  def inspect(io)
    io << "#<IO::FileDescriptor:"
    if closed?
      io << "(closed)"
    else
      io << " fd=" << @fd
    end
    io << ">"
    io
  end

  private def unbuffered_read(slice : Slice(UInt8))
    count = slice.size
    loop do
      bytes_read = LibC.read(@fd, slice.pointer(count).as(Void*), count)
      if bytes_read != -1
        return bytes_read
      end

      if Errno.value == Errno::EAGAIN
        wait_readable
      else
        raise Errno.new "Error reading file"
      end
    end
  ensure
    if (readers = @readers) && !readers.empty?
      add_read_event
    end
  end

  private def unbuffered_write(slice : Slice(UInt8))
    count = slice.size
    total = count
    loop do
      bytes_written = LibC.write(@fd, slice.pointer(count).as(Void*), count)
      if bytes_written != -1
        count -= bytes_written
        return total if count == 0
        slice += bytes_written
      else
        if Errno.value == Errno::EAGAIN
          wait_writable
          next
        elsif Errno.value == Errno::EBADF
          raise IO::Error.new "File not open for writing"
        else
          raise Errno.new "Error writing file"
        end
      end
    end
  ensure
    if (writers = @writers) && !writers.empty?
      add_write_event
    end
  end

  private def wait_readable
    wait_readable { |err| raise err }
  end

  private def wait_readable
    readers = (@readers ||= Deque(Fiber).new)
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
    writers = (@writers ||= Deque(Fiber).new)
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
    if readers = @readers
      Scheduler.enqueue readers
      readers.clear
    end

    if writers = @writers
      Scheduler.enqueue writers
      writers.clear
    end

    raise err if err
  end

  private def unbuffered_flush
    # Nothing
  end
end
