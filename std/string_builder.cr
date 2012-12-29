class StringBuilder
  def initialize
    @length = 0
    @parts = []
  end

  def <<(part)
    str = part.to_s
    @parts << str
    @length += str.length
  end

  def to_s
    str = String.new(@length)
    buffer = str.cstr
    @parts.each do |part|
      C.strcpy(buffer, part.cstr)
      buffer += part.length
    end
    str
  end
end