lib C
  fun atoi(str : Char*) : Int
  fun strncmp(s1 : Char*, s2 : Char*, n : Int) : Int
  fun strlen(s : Char*) : Int
  fun strcpy(dest : Char*, src : Char*) : Char*
  fun strcat(dest : Char*, src : Char*) : Char*
  fun strcmp(s1 : Char*, s2 : Char*) : Int
  fun strncpy(s1 : Char*, s2 : Char*, n : Int) : Char*
  fun sprintf(str : Char*, format : Char*, )
end

class String
  def self.from_cstr(chars)
    length = C.strlen(chars)
    str = Pointer.malloc(length + 5)
    str.as(Int).value = length
    C.strcpy((str + 4).as(Char), chars)
    str.as(String)
  end

  def to_i
    C.atoi @c.ptr
  end

  def [](index)
    @c.ptr[index]
  end

  def ==(other)
    C.strcmp(@c.ptr, other.cstr) == 0
  end

  def =~(regex)
    $~ = regex.match(self)
    $~ ? $~.begin(0) : nil
  end

  def +(other)
    new_string_buffer = Pointer.malloc(length + other.length + 1).as(Char)
    C.strcpy(new_string_buffer, @c.ptr)
    C.strcat(new_string_buffer, other.cstr)
    # new_string_buffer.as(String)
    String.from_cstr(new_string_buffer)
  end

  def length
    @length
  end

  def chars
    p = @c.ptr
    length.times do
      yield p.value
      p += 1
    end
  end

  def slice(start, count)
    new_string_buffer = Pointer.malloc(count + 1).as(Char)
    C.strncpy(new_string_buffer, @c.ptr + start, count)
    new_string_buffer[count] = '\0'
    # new_string_buffer.as(String)
    String.from_cstr(new_string_buffer)
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