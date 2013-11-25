class StringBuilder
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

  def length
    @length
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
