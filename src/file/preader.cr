# :nodoc:
class File::PReader < IO
  include IO::Buffered

  getter? closed = false

  @offset : Int64
  @bytesize : Int64
  @pos : Int64

  def initialize(@file : File, offset : Int, bytesize : Int)
    @offset = offset.to_i64
    @bytesize = bytesize.to_i64
    @pos = 0
  end

  def unbuffered_read(slice : Bytes) : Int64
    check_open

    count = slice.size
    count = Math.min(count, @bytesize - @pos)

    bytes_read = Crystal::System::FileDescriptor.pread(@file.fd, slice[0, count], @offset + @pos)

    @pos += bytes_read

    bytes_read
  end

  def unbuffered_write(slice : Bytes) : NoReturn
    raise IO::Error.new("Can't write to read-only IO")
  end

  def unbuffered_flush : NoReturn
    raise IO::Error.new("Can't flush read-only IO")
  end

  def unbuffered_rewind : Nil
    @pos = 0
  end

  def unbuffered_close : Nil
    @closed = true
  end
end
