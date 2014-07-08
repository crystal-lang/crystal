class StringIO
  include IO

  def initialize(contents = nil)
    @buffer = StringBuffer.new
    @buffer << contents if contents
    @pos = 0
  end

  def read(buffer, count)
    count = Math.min(count, @buffer.length - @pos)
    buffer.memcpy(@buffer.buffer + @pos, count)
    @pos += count
    count
  end

  def write(bytes, count)
    @buffer.append (bytes as UInt8*), count
  end

  def buffer
    @buffer
  end

  def to_s
    @buffer.to_s
  end
end
