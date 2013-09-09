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

  def buffer
    @array.buffer
  end

  def length
    @array.length
  end
end

