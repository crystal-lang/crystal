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
  fun sprintf(str : Char*, format : Char*, ...)
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

  def self.from_cstr(chars, length)
    str = Pointer.malloc(length + 5)
    str.as(Int).value = length
    C.strncpy(str.as(Char) + 4, chars, length)
    (str + length + 4).as(Char).value = '\0'
    str.as(String)
  end

  def self.new(capacity)
    str = Pointer.malloc(capacity + 5)
    buffer = str.as(String).cstr
    yield buffer
    str.as(Int).value = C.strlen(buffer)
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
    index += length if index < 0
    @c.ptr[index]
  end

  def [](range : Range)
    from = range.begin
    from += length if from < 0
    to = range.end
    to += length if to < 0
    to -= 1 if range.excludes_end?
    length = to - from + 1
    self[from, length]
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

  def *(times : Int)
    return "" if times <= 0
    str = StringBuilder.new
    times.times { str << self }
    str.inspect
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