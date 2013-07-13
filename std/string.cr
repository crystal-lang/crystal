require "range"
require "comparable"

lib C
  fun atoi(str : Char*) : Int32
  fun atof(str : Char*) : Float64
  fun strtof(str : Char*, endp : Char**) : Float32
  fun strncmp(s1 : Char*, s2 : Char*, n : Int32) : Int32
  fun strlen(s : Char*) : Int32
  fun strcpy(dest : Char*, src : Char*) : Char*
  fun strcat(dest : Char*, src : Char*) : Char*
  fun strcmp(s1 : Char*, s2 : Char*) : Int32
  fun strncpy(s1 : Char*, s2 : Char*, n : Int32) : Char*
  fun sprintf(str : Char*, format : Char*, ...) : Int32
end

class String
  include Comparable

  def self.from_cstr(chars)
    length = C.strlen(chars)
    str = Pointer(Char).malloc(length + 5)
    str.as(Int32).value = length
    C.strcpy(str.as(Char) + 4, chars)
    str.as(String)
  end

  def self.from_cstr(chars, length)
    str = Pointer(Char).malloc(length + 5)
    str.as(Int32).value = length
    C.strncpy(str.as(Char) + 4, chars, length)
    (str + length + 4).as(Char).value = '\0'
    str.as(String)
  end

  def self.new_with_capacity(capacity)
    str = Pointer(Char).malloc(capacity + 5)
    buffer = str.as(String).cstr
    yield buffer
    str.as(Int32).value = C.strlen(buffer)
    str.as(String)
  end

  def self.new_with_length(length)
    str = Pointer(Char).malloc(length + 5)
    buffer = str.as(String).cstr
    yield buffer
    buffer[length] = '\0'
    str.as(Int32).value = length
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

  def [](range : Range(Int, Int))
    from = range.begin
    from += length if from < 0
    to = range.end
    to += length if to < 0
    to -= 1 if range.excludes_end?
    length = to - from + 1
    self[from, length]
  end

  def [](start : Int, count : Int)
    String.new_with_length(count) do |buffer|
      C.strncpy(buffer, @c.ptr + start, count)
    end
  end

  def downcase
    String.new_with_length(length) do |buffer|
      length.times do |i|
        buffer[i] = @c.ptr[i].downcase
      end
    end
  end

  def upcase
    String.new_with_length(length) do |buffer|
      length.times do |i|
        buffer[i] = @c.ptr[i].upcase
      end
    end
  end

  def capitalize
    return self if length == 0

    String.new_with_length(length) do |buffer|
      buffer[0] = @c.ptr[0].upcase
      (length - 1).times do |i|
        buffer[i + 1] = @c.ptr[i + 1].downcase
      end
    end
  end

  def chomp
    excess = 0
    while (c = @c.ptr[length - 1 - excess]) == '\r' || c == '\n'
      excess += 1
    end

    if excess == 0
      self
    else
      self[0, length - excess]
    end
  end

  def strip
    excess_right = 0
    while @c.ptr[length - 1 - excess_right].whitespace?
      excess_right += 1
    end

    excess_left = 0
    while @c.ptr[excess_left].whitespace?
      excess_left += 1
    end

    if excess_right == 0 && excess_left == 0
      self
    else
      self[excess_left, length - excess_left - excess_right]
    end
  end

  def rstrip
    excess_right = 0
    while @c.ptr[length - 1 - excess_right].whitespace?
      excess_right += 1
    end

    if excess_right == 0
      self
    else
      self[0, length - excess_right]
    end
  end

  def lstrip
    excess_left = 0
    while @c.ptr[excess_left].whitespace?
      excess_left += 1
    end

    if excess_left == 0
      self
    else
      self[excess_left, length - excess_left]
    end
  end

  def empty?
    length == 0
  end

  def <=>(other : self)
    same?(other) ? 0 : C.strcmp(@c.ptr, other)
  end

  def =~(regex)
    match = regex.match(self)
    if match
      $~ = match
      match.begin(0)
    else
      $~ = MatchData::EMPTY
      nil
    end
  end

  def +(other)
    new_string_buffer = Pointer(Char).malloc(length + other.length + 1).as(Char)
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

  def index(c : Char, offset = 0)
    offset += length if offset < 0
    while offset < length
      return offset if cstr[offset] == c
      offset += 1
    end
    -1
  end

  def index(c : String, offset = 0)
    offset += length if offset < 0
    while offset < length
      return offset if (cstr + offset).memcmp(c.cstr, c.length)
      offset += 1
    end
    -1
  end

  def includes?(c : Char)
    index(c) >= 0
  end

  def includes?(str : String)
    index(str) >= 0
  end

  def split(separator : Char)
    ary = Array(String).new
    index = 0
    buffer = @c.ptr
    length.times do |i|
      if buffer[i] == separator
        ary.push String.from_cstr(buffer + index, i - index)
        index = i + 1
      end
    end
    if index != length
      ary.push String.from_cstr(buffer + index, length - index)
    end
    ary
  end

  def split(separator : String)
    ary = Array(String).new
    index = 0
    buffer = @c.ptr
    separator_length = separator.length

    # Special case: return all chars as strings
    if separator_length == 0
      each_char do |c|
        ary.push c.to_s
      end
      return ary
    end

    i = 0
    stop = length - separator.length + 1
    while i < stop
      if (buffer + i).memcmp(separator.cstr, separator_length)
        ary.push String.from_cstr(buffer + index, i - index)
        index = i + separator_length
        i += separator_length - 1
      end
      i += 1
    end
    if index != length
        ary.push String.from_cstr(buffer + index, length - index)
    end
    ary
  end

  def length
    @length
  end

  def reverse
    String.new_with_length(length) do |buffer|
      last = length - 1
      length.times do |i|
        buffer[last - i] = @c.ptr[i]
      end
    end
  end

  def each_char
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
    return false if str.length > length
    C.strncmp(cstr, str, str.length) == 0
  end

  def ends_with?(str)
    return false if str.length > length
    C.strncmp(cstr + length - str.length, str, str.length) == 0
  end

  def hash
    h = 0
    each_char do |c|
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
