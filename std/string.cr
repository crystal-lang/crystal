lib C
  fun atoi(str : String) : Int
end

class String
  def to_i
    C.atoi self
  end

  def ==(other)
    if self.length == other.length
      i = 0
      while i < self.length && self[i] == other[i]
        i += 1
      end
      i == self.length
    else
      false
    end
  end

  def inspect
    "\"#{to_s}\""
  end

  def to_s
    self
  end
end