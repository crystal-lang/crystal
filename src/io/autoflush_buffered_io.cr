require "./buffered_io"

class AutoflushBufferedIO(T) < BufferedIO(T)
  def write(slice : Slice(UInt8), count)
    index = slice[0, count.to_i32].rindex('\n'.ord.to_u8)
    if index
      flush
      index += 1
      @io.write(slice[0, index])
      slice += index
      count -= index
    end

    super(slice, count)
  end

  def write_byte(byte : UInt8)
    if byte == '\n'.ord.to_u8
      flush
      @io.write_byte byte
    else
      super
    end
  end
end
