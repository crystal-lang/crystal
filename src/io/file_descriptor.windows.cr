# An `IO` over a file descriptor.
class IO::FileDescriptor
  include Buffered

  # :nodoc:
  property overlappeds = Hash(LibWindows::Overlapped*, Fiber?).new

  def initialize(@handle : LibWindows::Handle)
    @edge_triggerable = false # HACK to make docs build in ci.
    @closed = false
    @pos = 0_u64
    @async = Scheduler.attach_to_completion_port(@handle, self)
  end

  # def self.fcntl(handle, cmd, arg = 0)
  #   r = LibC.fcntl handle, cmd, arg
  #   raise Errno.new("fcntl() failed") if r == -1
  #   r
  # end

  # def fcntl(cmd, arg = 0)
  #   self.class.fcntl @handle, cmd, arg
  # end

  def stat
    if LibC.fstat(@handle, out stat) != 0
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
    seek_value = LibC.lseek(@handle, offset, whence)
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
    check_open

    seek_value = LibC.lseek(@handle, 0, Seek::Current)
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

  def handle
    @handle
  end

  def finalize
    return if closed?

    close rescue nil
  end

  def closed?
    @closed
  end

  def tty?
    LibWindows.get_file_type(@handle) == LibWindows::FILE_TYPE_CHAR
  end

  def reopen(other : IO::FileDescriptor)
    if LibC.dup2(other.handle, self.handle) == -1
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
      io << " handle=" << @handle
    end
    io << ">"
    io
  end

  def pretty_print(pp)
    pp.text inspect
  end

  private def unbuffered_read(slice : Bytes)
    overlapped = Pointer(LibWindows::Overlapped).malloc
    overlapped.value = LibWindows::Overlapped.new
    overlapped.value.offset = @pos
    LibWindows.read_file(@handle, slice.pointer(slice.size), slice.size, out bytes_read, overlapped)
    status = LibWindows.get_last_error
    if status == WinError::ERROR_IO_PENDING
      @overlappeds[overlapped] = Fiber.current
      Scheduler.reschedule
      status = overlapped.value.status.to_u32
      bytes_read = overlapped.value.bytes_transfered
    elsif @async
      # See unbuffered_write
      @overlappeds[overlapped] = nil
    end

    if status == WinError::ERROR_SUCCESS
      @pos += bytes_read
      return bytes_read
    elsif status == WinError::ERROR_HANDLE_EOF
      return 0
    else
      raise WinError.new "ReadFile", status
    end
  end

  private def unbuffered_write(slice : Bytes)
    count = slice.size
    total = count
    loop do
      overlapped = Pointer(LibWindows::Overlapped).malloc
      overlapped.value = LibWindows::Overlapped.new
      overlapped.value.offset = @pos
      LibWindows.write_file(@handle, slice.pointer(count), count, out bytes_written, overlapped)
      status = LibWindows.get_last_error
      if status == WinError::ERROR_IO_PENDING
        @overlappeds[overlapped] = Fiber.current
        Scheduler.reschedule
        status = overlapped.value.status.to_u32
        bytes_written = overlapped.value.bytes_transfered
      elsif @async
        # Even though the operation already completed, this IO is asynchronous and a completion notification
        # will be triggered ai the IOCP (Scheduler). This means the overlapped pointer still remain valid.
        # It is saved in the @overlappeds Hash to prevent GC collection. We can return the results now and
        # simply ignore the event later.
        @overlappeds[overlapped] = nil
      end

      if status == WinError::ERROR_SUCCESS
        @pos += bytes_written
        count -= bytes_written
        return total if count == 0
        slice += bytes_written
      else
        raise WinError.new "WriteFile", status
      end
    end
  end

  # :nodoc:
  def resume_overlapped(overlapped_ptr)
    # @overlappeds will not contain this overlapped if the call returned success earlier
    @overlappeds.delete(overlapped_ptr).try &.resume
  end

  private def unbuffered_rewind
    seek(0, IO::Seek::Set)
    self
  end

  private def unbuffered_close
    return if @closed

    err = nil
    unless LibWindows.close_handle(@handle)
      err = "Error closing file"
    end

    @closed = true

    raise err if err
  end

  private def unbuffered_flush
    # Nothing
  end
end
