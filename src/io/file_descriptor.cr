require "crystal/system/file_handle"

# An `IO` over a file descriptor.
class IO::FileDescriptor
  include IO::Buffered

  getter handle : Crystal::System::FileHandle

  # Creates a new `IO::FileDescriptor` using the file descriptor *fd*.
  # TODO: deprecate this constructor in favour of creating a `FileHandle` manually.
  def self.new(fd : Int32, blocking = false)
    handle = Crystal::System::FileHandle.new(fd)
    new(handle, blocking)
  end

  # Creates a new `IO::FileDescriptor` using the file handle *handle*.
  def initialize(@handle : Crystal::System::FileHandle, blocking = false)
    unless blocking
      handle.blocking = false
    end
  end

  # Returns the time to wait when reading before raising an `IO::Timeout`.
  def read_timeout : Time::Span?
    @handle.read_timeout
  end

  # Sets the time to wait when reading before raising an `IO::Timeout`.
  def read_timeout=(value : Time::Span?) : Time::Span?
    @handle.read_timeout = value
  end

  # Set the number of seconds to wait when reading before raising an `IO::Timeout`.
  def read_timeout=(read_timeout : Number) : Number
    self.read_timeout = read_timeout.seconds

    read_timeout
  end

  # Returns the time to wait when writing before raising an `IO::Timeout`.
  def write_timeout : Time::Span?
    @handle.write_timeout
  end

  # Sets the time to wait when writing before raising an `IO::Timeout`.
  def write_timeout=(value : Time::Span?) : Time::Span?
    @handle.write_timeout = value
  end

  # Set the number of seconds to wait when writing before raising an `IO::Timeout`.
  def write_timeout=(write_timeout : Number) : Number
    self.write_timeout = write_timeout.seconds

    write_timeout
  end

  # Returns true if the `FileHandle` uses blocking IO.
  def blocking? : Bool
    @handle.blocking?
  end

  # Sets whether this `FileHandle` uses blocking IO.
  def blocking=(value : Bool) : Bool
    @handle.blocking = value
  end

  # Returns true if this `FileHandle` is closed when `Process.exec` is called.
  def close_on_exec? : Bool
    @handle.close_on_exec?
  end

  # Sets if this `FileHandle` is closed when `Process.exec` is called.
  def close_on_exec=(value : Bool) : Bool
    @handle.close_on_exec = value
  end

  # Returns a `File::Stat` object containing information about the file that
  # this `FileHandle` represents.
  def stat : File::Stat
    @handle.stat
  end

  # Seeks to a given offset relative to either the beginning, current position,
  # or end - depending on *whence*. Returns the new position in the file
  # measured in bytes from the beginning of the file.
  #
  # ```
  # File.write("testfile", "abc")
  #
  # file = File.new("testfile")
  # file.gets(3)                     # => "abc"
  # file.seek(1, IO::Seek::Set)      # => 1
  # file.gets(2)                     # => "bc"
  # file.seek(-1, IO::Seek::Current) # => 2
  # file.gets(1)                     # => "c"
  # ```
  def seek(offset : Number, whence : Seek = Seek::Set) : Int64
    check_open

    flush
    offset -= @in_buffer_rem.size if whence.current?
    position = @handle.seek(offset, whence)

    @in_buffer_rem = Bytes.empty

    position
  end

  # Same as `seek` but yields to the block after seeking and eventually seeks
  # back to the original position when the block returns.
  def seek(offset : Number, whence : Seek = Seek::Set) : Nil
    original_pos = pos
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
    seek(0, Seek::Current)
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
  def pos=(value : Number) : Number
    seek(value, Seek::Set)

    value
  end

  def finalize
    return if closed?

    close rescue nil
  end

  # Returns true if this `IO::FileDescriptor` has been closed.
  def closed? : Bool
    @handle.closed?
  end

  # Returns true if this `IO::FileDescriptor` is a handle of a terminal device (tty).
  # TODO: rename this to `terminal?`
  def tty? : Bool
    @handle.tty?
  end

  def reopen(other : IO::FileDescriptor) : IO::FileDescriptor
    @handle.reopen(other.handle)
    other
  end

  def inspect(io)
    io << "#<IO::FileDescriptor:"
    if closed?
      io << "(closed)"
    else
      io << " fd=" << @handle.platform_specific
    end
    io << ">"
    io
  end

  def pretty_print(pp)
    pp.text inspect
  end

  private def unbuffered_read(slice : Bytes)
    @handle.read(slice)
  end

  private def unbuffered_write(slice : Bytes)
    @handle.write(slice)
  end

  private def unbuffered_rewind
    @handle.rewind
  end

  private def unbuffered_close
    @handle.close
  end

  private def unbuffered_flush
    # Nothing
  end
end
