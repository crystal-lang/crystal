require "./syscall"
require "c/fcntl"

# An `IO` over a file descriptor.
class IO::FileDescriptor < IO
  include IO::Buffered
  include IO::Syscall

  @read_event : Event::Event?
  @write_event : Event::Event?

  def initialize(@fd : Int32, blocking = false)
    @closed = false

    unless blocking
      self.blocking = false
    end
  end

  def blocking
    fcntl(LibC::F_GETFL) & LibC::O_NONBLOCK == 0
  end

  def blocking=(value)
    current_flags = fcntl(LibC::F_GETFL)
    new_flags = current_flags
    if value
      new_flags &= ~LibC::O_NONBLOCK
    else
      new_flags |= LibC::O_NONBLOCK
    end
    fcntl(LibC::F_SETFL, new_flags) unless new_flags == current_flags
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
  # File.write("testfile", "abc")
  #
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
    offset -= @in_buffer_rem.size if whence.current?
    seek_value = LibC.lseek(@fd, offset, whence)

    if seek_value == -1
      raise Errno.new "Unable to seek"
    end

    @in_buffer_rem = Bytes.empty

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

  # Returns the current position (in bytes) in this `IO`.
  #
  # ```
  # File.write("testfile", "hello")
  #
  # file = File.new("testfile")
  # file.pos     # => 0
  # file.gets(2) # => "he"
  # file.pos     # => 2
  # ```
  def pos
    check_open

    seek_value = LibC.lseek(@fd, 0, Seek::Current)
    raise Errno.new "Unable to tell" if seek_value == -1

    seek_value - @in_buffer_rem.size
  end

  # Sets the current position (in bytes) in this `IO`.
  #
  # ```
  # File.write("testfile", "hello")
  #
  # file = File.new("testfile")
  # file.pos = 3
  # file.gets_to_end # => "lo"
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

  def pretty_print(pp)
    pp.text inspect
  end

  private def unbuffered_read(slice : Bytes)
    read_syscall_helper(slice, "Error reading file") do
      # `to_i32` is acceptable because `Slice#size` is a Int32
      LibC.read(@fd, slice, slice.size).to_i32
    end
  end

  private def unbuffered_write(slice : Bytes)
    write_syscall_helper(slice, "Error writing file") do |slice|
      LibC.write(@fd, slice, slice.size).tap do |return_code|
        if return_code == -1 && Errno.value == Errno::EBADF
          raise IO::Error.new "File not open for writing"
        end
      end
    end
  end

  private def add_read_event(timeout = @read_timeout)
    event = @read_event ||= Scheduler.create_fd_read_event(self)
    event.add timeout
    nil
  end

  private def add_write_event(timeout = @write_timeout)
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

    reschedule_waiting

    raise err if err
  end

  private def unbuffered_flush
    # Nothing
  end
end
