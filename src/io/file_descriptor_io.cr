class FileDescriptorIO
  include IO

  SEEK_SET = LibC::SEEK_SET
  SEEK_CUR = LibC::SEEK_CUR
  SEEK_END = LibC::SEEK_END

  def initialize(@fd)
  end

  def read(slice : Slice(UInt8), count)
    bytes_read = LibC.read(@fd, slice.pointer(count), LibC::SizeT.cast(count))
    if bytes_read == -1
      raise Errno.new "Error reading file"
    end
    bytes_read
  end

  def write(slice : Slice(UInt8), count)
    bytes_written = LibC.write(@fd, slice.pointer(count), LibC::SizeT.cast(count))
    if bytes_written == -1
      raise Errno.new "Error writing file"
    end
    bytes_written
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
  end

  def tty?
    LibC.isatty(fd) == 1
  end

  def to_fd_io
    self
  end
end
