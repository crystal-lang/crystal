class Char
  def succ
    (ord + 1).chr
  end

  def inspect
    "'#{to_s}'"
  end
end