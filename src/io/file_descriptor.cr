require "./syscall"
require "crystal/system/file_descriptor"

# An `IO` over a file descriptor.
class IO::FileDescriptor < IO
  include Crystal::System::FileDescriptor
  include IO::Buffered

  # The raw file-descriptor. It is defined to be an `Int`, but it's size is
  # platform-specific.
  getter fd

  def initialize(@fd, blocking = false)
    @closed = false

    unless blocking || {{flag?(:win32)}}
      self.blocking = false
    end
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
      Crystal::System::FileDescriptor.fcntl(@fd, cmd, arg)
    end
  {% end %}

  def stat
    system_stat
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
    system_reopen(other)

    other
  end

  def inspect(io)
    io << "#<IO::FileDescriptor:"
    if closed?
      io << "(closed)"
    else
      io << " fd=" << @fd
    end
    io << '>'
    io
  end

  def pretty_print(pp)
    pp.text inspect
  end

  private def unbuffered_rewind
    self.pos = 0
  end

  private def unbuffered_close
    return if @closed

    system_close ensure @closed = true
  end

  private def unbuffered_flush
    # Nothing
  end
end
