class Char
  def ==(other)
    false
  end

  def to_i
    ord
  end

  def succ
    (ord + 1).chr
  end

  def inspect
    "'#{to_s}'"
  end

  def to_s
    String.new(2) do |buffer|
      buffer.value = self
    end
  end
end