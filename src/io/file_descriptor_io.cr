class FileDescriptorIO
  include IO

  SEEK_SET = C::SEEK_SET
  SEEK_CUR = C::SEEK_CUR
  SEEK_END = C::SEEK_END

  def initialize(@fd)
  end

  def read(buffer : UInt8*, count)
    C.read(@fd, buffer, count.to_sizet)
  end

  def write(buffer : UInt8*, count)
    C.write(@fd, buffer, count.to_sizet)
  end

  def seek(amount, whence)
    C.lseek(@fd, amount.to_i64, whence)
  end

  def tell
    C.lseek(@fd, 0_i64, C::SEEK_CUR)
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
end
