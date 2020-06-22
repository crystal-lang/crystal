require "crystal/system/file_descriptor"

# An `IO` over a file descriptor.
class IO::FileDescriptor < IO
  include Crystal::System::FileDescriptor
  include IO::Buffered

  # The raw file-descriptor. It is defined to be an `Int`, but its size is
  # platform-specific.
  def fd
    @volatile_fd.get
  end

  def initialize(fd, blocking = nil)
    @volatile_fd = Atomic.new(fd)
    @closed = system_closed?

    if blocking.nil?
      blocking =
        case system_info.type
        when .pipe?, .socket?, .character_device?
          false
        else
          true
        end
    end

    unless blocking || {{flag?(:win32)}}
      self.blocking = false
    end
  end

  # :nodoc:
  def self.from_stdio(fd)
    Crystal::System::FileDescriptor.from_stdio(fd)
  end

  def blocking
    system_blocking?
  end

  def blocking=(value)
    self.system_blocking = value
  end

  def close_on_exec?
    system_close_on_exec?
  end

  def close_on_exec=(value : Bool)
    self.system_close_on_exec = value
  end

  {% unless flag?(:win32) %}
    def self.fcntl(fd, cmd, arg = 0)
      Crystal::System::FileDescriptor.fcntl(fd, cmd, arg)
    end

    def fcntl(cmd, arg = 0)
      Crystal::System::FileDescriptor.fcntl(fd, cmd, arg)
    end
  {% end %}

  def info
    system_info
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

    system_seek(offset, whence)

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

    system_pos - @in_buffer_rem.size
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

  def finalize
    return if closed?

    close rescue nil
  end

  def closed?
    @closed
  end

  def tty?
    system_tty?
  end

  def reopen(other : IO::FileDescriptor)
    return other if self.fd == other.fd
    system_reopen(other)

    other
  end

  def inspect(io : IO) : Nil
    io << "#<IO::FileDescriptor:"
    if closed?
      io << "(closed)"
    else
      io << " fd=" << fd
    end
    io << '>'
  end

  def pretty_print(pp)
    pp.text inspect
  end

  private def unbuffered_rewind
    self.pos = 0
  end

  private def unbuffered_close
    return if @closed

    # Set before the @closed state so the pending
    # IO::Evented readers and writers can be cancelled
    # knowing the IO is in a closed state.
    @closed = true
    system_close
  end

  private def unbuffered_flush
    # Nothing
  end
end
