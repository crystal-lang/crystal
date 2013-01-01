require "range"
require "comparable"

lib C
  fun atoi(str : Char*) : Int
  fun atof(str : Char*) : Double
  fun strtof(str : Char*, endp : Char**) : Float
  fun strncmp(s1 : Char*, s2 : Char*, n : Int) : Int
  fun strlen(s : Char*) : Int
  fun strcpy(dest : Char*, src : Char*) : Char*
  fun strcat(dest : Char*, src : Char*) : Char*
  fun strcmp(s1 : Char*, s2 : Char*) : Int
  fun strncpy(s1 : Char*, s2 : Char*, n : Int) : Char*
  fun sprintf(str : Char*, format : Char*, )
end

class String
  include Comparable

  def self.from_cstr(chars)
    length = C.strlen(chars)
    str = Pointer.malloc(length + 5)
    str.as(Int).value = length
    C.strcpy(str.as(Char) + 4, chars)
    str.as(String)
  end

  def self.new(length)
    str = Pointer.malloc(length + 5)
    str.as(Int).value = length
    str.as(String)
  end

  def to_i
    C.atoi @c.ptr
  end

  def to_f
    C.strtof @c.ptr, nil
  end

  def to_d
    C.atof @c.ptr
  end

  def [](index : Int)
    @c.ptr[index]
  end

  def [](range : Range)
    self[range.begin, range.end - range.begin + (range.excludes_end? ? 0 : 1)]
  end

  def [](start : Int, count : Int)
    new_string_buffer = Pointer.malloc(count + 1).as(Char)
    C.strncpy(new_string_buffer, @c.ptr + start, count)
    new_string_buffer[count] = '\0'
    String.from_cstr(new_string_buffer)
  end

  def <=>(other : self)
    Object.same?(self, other) ? 0 : C.strcmp(@c.ptr, other)
  end

  def =~(regex)
    $~ = regex.match(self)
    $~ ? $~.begin(0) : nil
  end

  def +(other)
    new_string_buffer = Pointer.malloc(length + other.length + 1).as(Char)
    C.strcpy(new_string_buffer, @c.ptr)
    C.strcat(new_string_buffer, other)
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

  def inspect
    "\"#{to_s}\""
  end

  def starts_with?(str)
    C.strncmp(cstr, str, str.length) == 0
  end

  def hash
    h = 0
    chars do |c|
      h = 31 * h + c.ord
    end
    h
  end

  def to_s
    self
  end

  def cstr
    @c.ptr
  end
end