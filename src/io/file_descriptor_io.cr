class FileDescriptorIO
  include IO

  SEEK_SET = LibC::SEEK_SET
  SEEK_CUR = LibC::SEEK_CUR
  SEEK_END = LibC::SEEK_END

  def initialize(@fd, blocking = false)
    unless blocking
      before = LibC.fcntl(@fd, LibC::FCNTL::F_GETFL)
      LibC.fcntl(@fd, LibC::FCNTL::F_SETFL, before | LibC::O_NONBLOCK)
    end

    @readers = [] of Fiber
    @writers = [] of Fiber
    @event = Scheduler.create_fd_events(self)
  end

  def read(slice : Slice(UInt8), count)
    loop do
      bytes_read = LibC.read(@fd, slice.pointer(count), LibC::SizeT.cast(count))
      if bytes_read == -1
        if LibC.errno == Errno::EAGAIN
          @readers << Fiber.current
          Scheduler.reschedule
        else
          raise Errno.new "Error reading file"
        end
      else
        return bytes_read
      end
    end
  end

  def resume_read
    if reader = @readers.pop?
      reader.resume
    end
  end

  def resume_write
    if writer = @writers.pop?
      writer.resume
    end
  end

  def write(slice : Slice(UInt8), count)
    loop do
      bytes_written = LibC.write(@fd, slice.pointer(count), LibC::SizeT.cast(count))
      if bytes_written == -1
        if LibC.errno == Errno::EAGAIN
          @writers << Fiber.current
          Scheduler.reschedule
          next
        else
          raise Errno.new "Error writing file"
        end
      end
      count -= bytes_written
      return if count == 0
      slice += bytes_written
    end
  end

  def seek(amount, whence = SEEK_SET)
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

  def close
    if LibC.close(@fd) != 0
      raise Errno.new("Error closing file")
    end
    Scheduler.destroy_fd_events(@event)
  end

  def tty?
    LibC.isatty(fd) == 1
  end

  def to_fd_io
    self
  end
end
