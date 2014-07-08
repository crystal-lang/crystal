class StringBuilder
  getter length

  def initialize
    @length = 0
    @parts = Array(String).new
  end

  def initialize(string : String)
    @length = string.length
    @parts = [string]
  end

  def clear
    @length = 0
    @parts.clear
  end

  def <<(part)
    str = part.to_s
    @parts << str
    @length += str.length
    self
  end

  def to_s(io)
    io << String.new_with_length(@length) do |cstr|
      buffer = cstr
      @parts.each do |part|
        buffer.memcpy(part.cstr, part.length)
        buffer += part.length
      end
    end
  end
end
