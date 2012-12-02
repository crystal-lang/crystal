lib C
  fun atoi(str : String) : Int
  fun strncmp(s1 : String, s2 : String, n : Int) : Int
  fun strlen(s : String) : Int
  fun strcpy(dest : ptr Char, src : String) : String
  fun strcat(dest : ptr Char, src : String) : String
end

class String
  def to_i
    C.atoi self
  end

  def [](index)
    ptr(@c)[index]
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

  def +(other)
    new_string_buffer = Pointer.malloc(self.length + other.length + 1)
    new_string = C.strcpy(new_string_buffer, self)
    C.strcat(new_string_buffer, other)
    new_string
  end

  def length
    C.strlen self
  end

  def chars
    p = ptr(@c)
    (0...length).each do |i|
      yield p[i]
    end
  end

  def inspect
    "\"#{to_s}\""
  end

  def starts_with?(str)
    C.strncmp(self, str, str.length) == 0
  end

  def to_s
    self
  end
end