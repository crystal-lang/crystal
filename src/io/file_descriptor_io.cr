class FileDescriptorIO
  include BufferedIOMixin

  SEEK_SET = 0
  SEEK_CUR = 1
  SEEK_END = 2

  private getter! readers
  private getter! writers

  property? flush_on_newline
  property? sync

  def initialize(fd, blocking = false, edge_triggerable = true)
    @edge_triggerable = !!edge_triggerable
    @flush_on_newline = false
    @sync = false
    @closed = false
    @fd = fd
    @in_buffer_rem = Slice.new(Pointer(UInt8).null, 0)
    @out_count = 0

    unless blocking
      before = fcntl(LibC::FCNTL::F_GETFL)
      fcntl(LibC::FCNTL::F_SETFL, before | LibC::O_NONBLOCK)
      if @edge_triggerable
        @event = Scheduler.create_fd_events(self)
      end
      @readers = [] of Fiber
      @writers = [] of Fiber
    end
  end

  def resume_read
    if reader = readers.pop?
      reader.resume
    end
  end

  def resume_write
    if writer = writers.pop?
      writer.resume
    end
  end

  def seek(amount, whence = SEEK_SET)
    flush
    LibC.lseek(@fd, LibC::SizeT.cast(amount), whence)
  end

  def tell
    LibC.lseek(@fd, LibC::SizeT.zero, LibC::SEEK_CUR)
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

  def reopen(other : FileDescriptorIO)
    if LibC.dup2(other.fd, self.fd) == -1
      raise Errno.new("Could not reopen file descriptor")
    end

    other
  end

  def to_fd_io
    self
  end

  def close_on_exec=(arg : Bool)
    fcntl(LibC::FCNTL::FD_CLOEXEC, arg ? 1 : 0)
  end

  def fcntl cmd, arg = 0
    r = LibC.fcntl @fd, cmd, arg
    raise Errno.new("fcntl() failed") if r == -1
    r
  end

  private def unbuffered_read(slice : Slice(UInt8), count)
    loop do
      bytes_read = LibC.read(@fd, slice.pointer(count), LibC::SizeT.cast(count))
      if bytes_read == -1
        if LibC.errno == Errno::EAGAIN
          readers << Fiber.current
          if @edge_triggerable
            Scheduler.reschedule
          else
            event = Scheduler.create_fd_read_event(self)
            Scheduler.reschedule
            Scheduler.destroy_fd_events(event)
          end
        else
          raise Errno.new "Error reading file"
        end
      else
        return bytes_read
      end
    end
  end

  private def unbuffered_write(slice : Slice(UInt8), count)
    total = count
    loop do
      bytes_written = LibC.write(@fd, slice.pointer(count), LibC::SizeT.cast(count))
      if bytes_written == -1
        if LibC.errno == Errno::EAGAIN
          writers << Fiber.current
          if @edge_triggerable
            Scheduler.reschedule
          else
            event = Scheduler.create_fd_write_event(self)
            Scheduler.reschedule
            Scheduler.destroy_fd_events(event)
          end
          next
        else
          raise Errno.new "Error writing file"
        end
      end
      count -= bytes_written
      return total if count == 0
      slice += bytes_written
    end
  end

  private def unbuffered_rewind
    seek(0, SEEK_SET)
    self
  end

  private def unbuffered_close
    if closed?
      raise IO::Error.new "closed stream"
    end

    if LibC.close(@fd) != 0
      raise Errno.new("Error closing file")
    end

    @closed = true

    if event = @event
      Scheduler.destroy_fd_events(event)
    end
  end

  private def unbuffered_flush
    # Nothing
  end
end
