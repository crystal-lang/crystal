# An IO over a file descriptor.
class IO::FileDescriptor
  include Buffered

  # :nodoc:
  property overlappeds = Hash(LibWindows::Overlapped*, Fiber).new

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

  # Returns the current position (in bytes) in this IO.
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

  # Sets the current position (in bytes) in this IO.
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
    overlapped = LibWindows::Overlapped.new
    overlapped.status = 0
    overlapped.bytes_transfered = 0
    overlapped.offset = @pos
    overlapped.event = nil

    ret = LibWindows.read_file(@handle, slice.pointer(slice.size), slice.size, out bytes_read, pointerof(overlapped))
    if ret || LibWindows.get_last_error == WinError::ERROR_IO_PENDING
      if @async
        @overlappeds[pointerof(overlapped)] = Fiber.current
        sleep
        if overlapped.status != WinError::ERROR_SUCCESS
          raise WinError.new "ReadFile", overlapped.status.to_u32
        end
        bytes_read = overlapped.bytes_transfered
      end
      @pos += bytes_read
      return bytes_read
    elsif LibWindows.get_last_error == WinError::ERROR_HANDLE_EOF
      return 0
    else
      raise WinError.new "ReadFile"
    end
  end

  private def unbuffered_write(slice : Bytes)
    count = slice.size
    total = count
    loop do
      overlapped = LibWindows::Overlapped.new
      overlapped.status = 0
      overlapped.bytes_transfered = 0
      overlapped.offset = @pos
      overlapped.event = nil
      ret = LibWindows.write_file(@handle, slice.pointer(count), count, out bytes_written, pointerof(overlapped))
      if ret || LibWindows.get_last_error == WinError::ERROR_IO_PENDING
        if @async
          @overlappeds[pointerof(overlapped)] = Fiber.current
          sleep
          if overlapped.status != WinError::ERROR_SUCCESS
            raise WinError.new "WriteFile", overlapped.status.to_u32
          end
          bytes_written = overlapped.bytes_transfered
        end
        @pos += bytes_written
        count -= bytes_written
        return total if count == 0
        slice += bytes_written
      else
        raise WinError.new "WriteFile"
      end
    end
  end

  # :nodoc:
  def resume_overlapped(overlapped_ptr)
    @overlappeds.delete(overlapped_ptr).try &.resume
    # TODO: Can it possibly not be found?
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
