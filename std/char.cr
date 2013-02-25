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

  def whitespace?
    self == ' ' || self == '\t' || self == '\n' || self == '\v' || self == '\f' || self == '\r'
  end

  def downcase
    if 'A' <= self && self <= 'Z'
      (self.ord + 32).chr
    else
      self
    end
  end

  def upcase
    if 'a' <= self && self <= 'z'
      (self.ord - 32).chr
    else
      self
    end
  end

  def to_i
    ord
  end

  def hash
    to_i
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