# :nodoc:
class File::PReader < IO
  include IO::Buffered

  getter? closed = false

  def initialize(@file : File, @offset : Int32, @bytesize : Int32)
    @pos = 0
  end

  def unbuffered_read(slice : Bytes)
    check_open

    count = slice.size
    count = Math.min(count, @bytesize - @pos)

    bytes_read = Crystal::System::FileDescriptor.pread(@file.fd, slice[0, count], @offset + @pos)

    @pos += bytes_read

    bytes_read
  end

  def unbuffered_write(slice : Bytes)
    raise IO::Error.new("Can't write to read-only IO")
  end

  def unbuffered_flush
    raise IO::Error.new("Can't flush read-only IO")
  end

  def unbuffered_rewind
    @pos = 0
  end

  def unbuffered_close
    @closed = true
  end
end
