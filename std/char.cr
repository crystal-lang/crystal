class Char
  def ==(other)
    false
  end

  def -(other : Char)
    ord - other.ord
  end

  def digit?
    '0' <= self && self <= '9'
  end

  def alpha?
    ('a' <= self && self <= 'z') ||
      ('A' <= self && self <= 'Z')
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