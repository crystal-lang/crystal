class StringBuilder
  def initialize
    @length = 0
    @parts = Array(String).new
  end

  def <<(part)
    str = part.to_s
    @parts << str
    @length += str.length
    self
  end

  def to_s
    String.new_with_length(@length) do |cstr|
      buffer = cstr
      @parts.each do |part|
        C.strcpy(buffer, part.cstr)
        buffer += part.length
      end
    end
  end
end
