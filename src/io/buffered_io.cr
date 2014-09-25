class BufferedIO(T)
  include IO

  def initialize(@io : T)
    @buffer :: UInt8[16384]
    @buffer_rem = @buffer.to_slice[0, 0]
    @out_buffer = StringIO.new
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
    @io << @out_buffer.to_s
    @out_buffer = StringIO.new
  end

  private def fill_buffer
    length = @io.read(@buffer.to_slice).to_i
    @buffer_rem = @buffer.to_slice[0, length]
  end
end
