class FileDescriptorIO
  include IO

  SEEK_SET = C::SEEK_SET
  SEEK_CUR = C::SEEK_CUR
  SEEK_END = C::SEEK_END

  def initialize(@fd)
  end

  def read(slice : Slice(UInt8), count)
    C.read(@fd, slice.pointer(count), C::SizeT.cast(count))
  end

  def write(slice : Slice(UInt8), count)
    C.write(@fd, slice.pointer(count), C::SizeT.cast(count))
  end

  def seek(amount, whence)
    C.lseek(@fd, C::SizeT.cast(amount), whence)
  end

  def tell
    C.lseek(@fd, C::SizeT.zero, C::SEEK_CUR)
  end

  def stat
    if C.fstat(@fd, out stat) != 0
      raise Errno.new("Unable to get stat")
    end
    File::Stat.new(stat)
  end

  def fd
    @fd
  end

  def close
    if C.close(@fd) != 0
      raise Errno.new("Error closing file")
    end
  end

  def tty?
    C.isatty(fd) == 1
  end
end
