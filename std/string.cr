lib C
  fun atoi(str : ptr Char) : Int
  fun strncmp(s1 : ptr Char, s2 : ptr Char, n : Int) : Int
  fun strlen(s : ptr Char) : Int
  fun strcpy(dest : ptr Char, src : ptr Char) : ptr Char
  fun strcat(dest : ptr Char, src : ptr Char) : ptr Char
  fun strcmp(s1 : ptr Char, s2 : ptr Char) : Int
end

class String
  def to_i
    C.atoi @c.ptr
  end

  def [](index)
    @c.ptr[index]
  end

  def ==(other)
    C.strcmp(@c.ptr, other.cstr) == 0
  end

  def +(other)
    new_string_buffer = Pointer.malloc(length + other.length + 1).as(Char)
    C.strcpy(new_string_buffer, @c.ptr)
    C.strcat(new_string_buffer, other.cstr)
    new_string_buffer.as(String)
  end

  def length
    C.strlen @c.ptr
  end

  def chars
    p = @c.ptr
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
    @c.ptr
  end
end