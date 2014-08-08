class BufferedIO(T)
  include IO

  def initialize(@io : T)
    @buffer = StaticArray(UInt8, 16384).new
    @buffer_rem = @buffer.to_slice[0, 0]
    @out_buffer = StringIO.new
  end

  def gets
    String.build do |buffer|
      loop do
        fill_buffer if @buffer_rem.empty?

        if @buffer_rem.empty?
          if buffer.length == 0
            return nil
          else
            break
          end
        end

        endl = @buffer_rem.index('\n'.ord.to_u8)
        if endl
          buffer << String.new(@buffer_rem.pointer, endl + 1)
          @buffer_rem += (endl + 1)
          break
        else
          buffer << String.new(@buffer_rem.pointer, @buffer_rem.length)
          @buffer_rem += @buffer_rem.length
        end
      end
    end
  end

  def read(buffer : Slice(UInt8), count)
    fill_buffer if @buffer_rem_size == 0
    count = Math.min(count, @buffer_rem_size)
    buffer.copy_from(@buffer_rem, count)
    @buffer_rem += count
    # @buffer_rem_size -= count
    count
  end

  def write(buffer : Slice(UInt8), count)
    @out_buffer.write buffer, count
  end

  def flush
    @io << @out_buffer.to_s
    @out_buffer = StringIO.new
  end

  def fill_buffer
    length = @io.read(@buffer.to_slice).to_i
    @buffer_rem = @buffer.to_slice[0, length]
  end
end
