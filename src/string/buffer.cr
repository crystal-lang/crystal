class String::Buffer
  def initialize(capacity)
    @array = Array(Char).new(capacity)
  end

  def <<(c : Char)
    @array << c
  end

  def <<(obj)
    obj.to_s.each_char do |char|
      @array << char
    end
  end

  def clear
    @array.clear
  end

  def length
    @array.length
  end

  def to_s
    String.new @array.buffer, length
  end
end

