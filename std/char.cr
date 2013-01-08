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
    str = String.new(2)
    str.cstr.value = self
    str
  end
end