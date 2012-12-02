lib C
  fun atoi(str : ptr Char) : Int
  fun strncmp(s1 : ptr Char, s2 : ptr Char, n : Int) : Int
  fun strlen(s : ptr Char) : Int
  fun strcpy(dest : ptr Char, src : ptr Char) : String
  fun strcat(dest : ptr Char, src : ptr Char) : String
end

class String
  def to_i
    C.atoi ptr(@c)
  end

  def [](index)
    ptr(@c)[index]
  end

  def ==(other)
    if length == other.length
      i = 0
      while i < length && self[i] == other[i]
        i += 1
      end
      i == length
    else
      false
    end
  end

  def +(other)
    new_string_buffer = Pointer.malloc(length + other.length + 1)
    new_string = C.strcpy(new_string_buffer, ptr(@c))
    C.strcat(new_string_buffer, other.cstr)
    new_string
  end

  def length
    C.strlen ptr(@c)
  end

  def chars
    p = ptr(@c)
    length.times do
      yield p.value
      p += 1
    end
  end

  def inspect
    "\"#{to_s}\""
  end

  def starts_with?(str)
    C.strncmp(cstr, str.cstr, str.length) == 0
  end

  def to_s
    self
  end

  def cstr
    ptr(@c)
  end
end