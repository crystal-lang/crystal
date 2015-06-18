require "./buffered_io_mixin"

class BufferedIO(T)
  include BufferedIOMixin

  def initialize(@io : T)
    @in_buffer_rem = Slice.new(Pointer(UInt8).null, 0)
    @out_count = 0
    @flush_on_newline = false
    @sync = false
  end

  def self.new(io)
    buffered_io = new(io)
    yield buffered_io
    buffered_io.flush
    io
  end

  private def unbuffered_read(slice : Slice(UInt8), count)
    @io.read(slice, count)
  end

  private def unbuffered_write(slice : Slice(UInt8), count)
    @io.write(slice, count)
  end

  private def unbuffered_flush
    @io.flush
  end

  def fd
    @io.fd
  end

  private def unbuffered_close
    @io.close
  end

  def closed?
    @io.closed?
  end

  def to_fd_io
    @io.to_fd_io
  end

  private def unbuffered_rewind
    @io.rewind
  end
end
