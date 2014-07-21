class BufferedIO(T)
  include IO

  def initialize(@io : T)
    @buffer = @buffer_rem = Pointer(UInt8).malloc(16 * 1024)
    @buffer_rem_size = 0
    @out_buffer = StringIO.new
  end

  def gets
    String.build do |buffer|
      loop do
        fill_buffer if @buffer_rem_size == 0
        if @buffer_rem_size <= 0
          if buffer.length == 0
            return nil
          else
            break
          end
        end

        endl = @buffer_rem.as_enumerable(@buffer_rem_size).index('\n'.ord.to_u8)
        if endl
          buffer << String.new(@buffer_rem as UInt8*, endl + 1)
          @buffer_rem_size -= (endl + 1)
          @buffer_rem += (endl + 1)
          break
        else
          buffer << String.new(@buffer_rem as UInt8*, @buffer_rem_size)
          @buffer_rem_size = 0
        end
      end
    end
  end

  def read(buffer : UInt8*, count)
    fill_buffer if @buffer_rem_size == 0
    count = Math.min(count, @buffer_rem_size)
    buffer.memcpy(@buffer_rem, count)
    @buffer_rem += count
    @buffer_rem_size -= count
    count
  end

  def write(buffer, count)
    @out_buffer.write buffer, count
  end

  def flush
    @io << @out_buffer.to_s
    @out_buffer = StringIO.new
  end

  def fill_buffer
    @buffer_rem_size = @io.read(@buffer, 16 * 1024).to_i
    @buffer_rem = @buffer
  end
end
