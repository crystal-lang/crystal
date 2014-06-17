class FileDescriptorIO
  include IO

  def initialize(@fd)
  end

  def read(buffer : UInt8*, count)
    C.read(@fd, buffer, count.to_sizet)
  end

  def read_nonblock(length)
    before = C.fcntl(fd, C::FCNTL::F_GETFL)
    C.fcntl(fd, C::FCNTL::F_SETFL, before | C::FD::O_NONBLOCK)

    begin
      buffer = Pointer(UInt8).malloc(length)
      read_length = read(buffer, length)
      if read_length == 0 || C.errno == C::EWOULDBLOCK || C.errno == C::EAGAIN
        # TODO: raise exception when errno != 0
        nil
      else
        String.new(buffer, read_length.to_i)
      end
    ensure
      C.fcntl(fd, C::FCNTL::F_SETFL, before)
    end
  end

  def write(buffer : UInt8*, count)
    C.write(@fd, buffer, count.to_sizet)
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

STDIN = FileDescriptorIO.new(0)
STDOUT = FileDescriptorIO.new(1)
STDERR = FileDescriptorIO.new(2)
