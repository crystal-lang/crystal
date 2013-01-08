class StringBuilder
  def initialize
    @length = 0
    @parts = []
  end

  def <<(part)
    str = part.to_s
    @parts << str
    @length += str.length
    self
  end

  def to_s
    String.new(@length) do |cstr|
      buffer = cstr
      @parts.each do |part|
        C.strcpy(buffer, part.cstr)
        buffer += part.length
      end
      @length
    end
  end
end