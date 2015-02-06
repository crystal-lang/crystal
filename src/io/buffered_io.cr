class BufferedIO(T)
  include IO

  def initialize(@io : T)
    @buffer :: UInt8[16384]
    @buffer_rem = @buffer.to_slice[0, 0]
    @out_buffer = StringIO.new
  end

  def self.new(io)
    buffered_io = new(io)
    yield buffered_io
    buffered_io.flush
    io
  end

  def gets
    String.build do |buffer|
      loop do
        fill_buffer if @buffer_rem.empty?

        if @buffer_rem.empty?
          if buffer.bytesize == 0
            return nil
          else
            break
          end
        end

        endl = @buffer_rem.index('\n'.ord.to_u8)
        if endl
          buffer.write @buffer_rem, endl + 1
          @buffer_rem += (endl + 1)
          break
        else
          buffer.write @buffer_rem
          @buffer_rem += @buffer_rem.length
        end
      end
    end
  end

  def read_byte
    fill_buffer if @buffer_rem.empty?
    if @buffer_rem.empty?
      nil
    else
      b = @buffer_rem[0]
      @buffer_rem += 1
      b
    end
  end

  def read_char
    return super unless @buffer_rem.length >= 4

    first = @buffer_rem[0].to_u32
    if first < 0x80
      @buffer_rem += 1
      return first.chr
    end

    second = (@buffer_rem[1] & 0x3f).to_u32
    if first < 0xe0
      @buffer_rem += 2
      return ((first & 0x1f) << 6 | second).chr
    end

    third = (@buffer_rem[2] & 0x3f).to_u32
    if first < 0xf0
      @buffer_rem += 3
      return ((first & 0x0f) << 12 | (second << 6) | third).chr
    end

    fourth = (@buffer_rem[3] & 0x3f).to_u32
    if first < 0xf8
      @buffer_rem += 4
      return ((first & 0x07) << 18 | (second << 12) | (third << 6) | fourth).chr
    end

    raise "Invalid byte sequence in UTF-8 string"
  end

  def read(slice : Slice(UInt8), count)
    fill_buffer if @buffer_rem.empty?
    count = Math.min(count, @buffer_rem.length)
    slice.copy_from(@buffer_rem.pointer(count), count)
    @buffer_rem += count
    count
  end

  def write(slice : Slice(UInt8), count)
    @out_buffer.write slice, count
  end

  def flush
    @io << @out_buffer
    @out_buffer.clear
  end

  def fd
    @io.fd
  end

  def to_fd_io
    @io.to_fd_io
  end

  private def fill_buffer
    length = @io.read(@buffer.to_slice).to_i
    @buffer_rem = @buffer.to_slice[0, length]
  end
end
