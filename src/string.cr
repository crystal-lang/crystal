require "range"
require "comparable"
require "string/buffer"
require "string/formatter"

lib C
  fun atoi(str : Char*) : Int32
  fun atoll(str : Char*) : Int64
  fun atof(str : Char*) : Float64
  fun strtof(str : Char*, endp : Char**) : Float32
  fun strncmp(s1 : Char*, s2 : Char*, n : Int32) : Int32
  fun strlen(s : Char*) : Int32
  fun strcpy(dest : Char*, src : Char*) : Char*
  fun strcat(dest : Char*, src : Char*) : Char*
  fun strcmp(s1 : Char*, s2 : Char*) : Int32
  fun strncpy(s1 : Char*, s2 : Char*, n : Int32) : Char*
  fun sprintf(str : Char*, format : Char*, ...) : Int32
  fun memcpy(dest : Void*, src : Void*, num : Int32) : Void*
end

class String
  include Comparable

  def self.new(chars : Char*)
    length = C.strlen(chars)
    str = Pointer(Char).malloc(length + 5)
    (str as Int32*).value = length
    C.strcpy((str as Char*) + 4, chars)
    str as String
  end

  def self.new(chars : Char*, length)
    str = Pointer(Char).malloc(length + 5)
    (str as Int32*).value = length
    C.strncpy((str as Char*) + 4, chars, length)
    ((str + length + 4) as Char*).value = '\0'
    str as String
  end

  def self.new_with_capacity(capacity)
    str = Pointer(Char).malloc(capacity + 5)
    buffer = (str as String).cstr
    yield buffer
    (str as Int32*).value = C.strlen(buffer)
    str as String
  end

  def self.new_with_length(length)
    str = Pointer(Char).malloc(length + 5)
    buffer = (str as String).cstr
    yield buffer
    buffer[length] = '\0'
    (str as Int32*).value = length
    str as String
  end

  def self.new_from_buffer(capacity = 16)
    buffer = Buffer.new(capacity)
    yield buffer
    buffer.to_s
  end

  def self.build
    builder = StringBuilder.new
    yield builder
    builder.to_s
  end

  def to_i
    C.atoi cstr
  end

  def to_i8
    to_i.to_i8
  end

  def to_i16
    to_i.to_i16
  end

  def to_i32
    to_i
  end

  def to_i64
    C.atoll cstr
  end

  def to_u8
    to_i.to_u8
  end

  def to_u16
    to_i.to_u16
  end

  def to_u32
    to_i64.to_u32
  end

  def to_u64
    to_i64.to_u64
  end

  def to_f
    to_f64
  end

  def to_f32
    C.strtof cstr, nil
  end

  def to_f64
    C.atof cstr
  end

  def [](index : Int)
    index += length if index < 0
    raise IndexOutOfBounds.new if index >= length || index < 0
    cstr[index]
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
      C.strncpy(buffer, cstr + start, count)
    end
  end

  def downcase
    String.new_with_length(length) do |buffer|
      length.times do |i|
        buffer[i] = cstr[i].downcase
      end
    end
  end

  def upcase
    String.new_with_length(length) do |buffer|
      length.times do |i|
        buffer[i] = cstr[i].upcase
      end
    end
  end

  def capitalize
    return self if length == 0

    String.new_with_length(length) do |buffer|
      buffer[0] = cstr[0].upcase
      (length - 1).times do |i|
        buffer[i + 1] = cstr[i + 1].downcase
      end
    end
  end

  def chomp
    excess = 0
    while (c = cstr[length - 1 - excess]) == '\r' || c == '\n'
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
    while cstr[length - 1 - excess_right].whitespace?
      excess_right += 1
    end

    excess_left = 0
    while cstr[excess_left].whitespace?
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
    while cstr[length - 1 - excess_right].whitespace?
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
    while cstr[excess_left].whitespace?
      excess_left += 1
    end

    if excess_left == 0
      self
    else
      self[excess_left, length - excess_left]
    end
  end

  def replace(&block : Char -> String)
    String.new_from_buffer(length) do |buffer|
      each_char do |my_char|
        replacement = yield my_char
        if replacement
          buffer << replacement
        else
          buffer << my_char
        end
      end
    end
  end

  def replace(char : Char, replacement : String)
    replace { |my_char| char == my_char ? replacement : nil }
  end

  def replace(char : Char, replacement : Char)
    replace(char, replacement.to_s)
  end

  def replace(pattern : Regexp)
    len = length
    offset = 0
    buffer = String::Buffer.new(len)
    while true
      match = pattern.match(self, offset)
      if match
        index = match.begin(0)
        if index > offset
          offset.upto(index - 1) do |i|
            buffer << cstr[i]
          end
        end
        str = match[0]
        replacement = yield str
        buffer << replacement
        offset = index + str.length
      else
        break
      end
    end

    if offset < len
      offset.upto(len - 1) do |i|
        buffer << cstr[i]
      end
    end

    buffer.to_s
  end

  def delete(char : Char)
    new_length = length
    str = Pointer(Char).malloc(length + 5)
    i = 4
    each_char do |my_char|
      if my_char == char
        new_length -= 1
      else
        str[i] = my_char
        i += 1
      end
    end
    (str as Int32*).value = new_length
    str[i] = '\0'
    str as String
  end

  def empty?
    @length == 0
  end

  def <=>(other : self)
    same?(other) ? 0 : C.strcmp(cstr, other)
  end

  def =~(regex)
    match = regex.match(self)
    match ? match.begin(0) : nil
  end

  def +(other)
    String.new_with_length(length + other.length) do |buffer|
      buffer.memcpy(cstr, length)
      (buffer + length).memcpy(other.cstr, other.length)
    end
  end

  def *(times : Int)
    return "" if times <= 0 || length == 0

    total_length = length * times
    String.new_with_length(total_length) do |buffer|
      buffer.memcpy(cstr, length)
      n = length

      while n <= total_length / 2
        (buffer + n).memcpy(buffer, n)
        n *= 2
      end

      (buffer + n).memcpy(buffer, total_length - n)
    end
  end

  def index(c : Char, offset = 0)
    offset += length if offset < 0
    return -1 if offset < 0

    while offset < length
      return offset if cstr[offset] == c
      offset += 1
    end
    -1
  end

  def index(c : String, offset = 0)
    offset += length if offset < 0
    return -1 if offset < 0

    end_length = length - c.length
    while offset <= end_length
      return offset if (cstr + offset).memcmp(c.cstr, c.length)
      offset += 1
    end
    -1
  end

  def rindex(c : Char, offset = length - 1)
    offset += length if offset < 0
    return -1 if offset < 0

    while offset >= 0
      return offset if cstr[offset] == c
      offset -= 1
    end
    -1
  end

  def rindex(c : String, offset = length - c.length)
    offset += length if offset < 0
    return -1 if offset < 0

    offset = length - c.length if offset > length - c.length
    while offset >= 0
      return offset if (cstr + offset).memcmp(c.cstr, c.length)
      offset -= 1
    end
    -1
  end

  def includes?(c : Char)
    index(c) >= 0
  end

  def includes?(str : String)
    index(str) >= 0
  end

  def split
    ary = Array(String).new
    index = 0
    buffer = cstr
    len = length
    i = 0
    looking_for_space = false
    while i < len
      if looking_for_space
        while i < len
          c = buffer[i]
          i += 1
          if c.whitespace?
            ary.push String.new(buffer + index, i - 1 - index)
            looking_for_space = false
            break
          end
        end
      else
        while i < len
          c = buffer[i]
          i += 1
          unless c.whitespace?
            index = i - 1
            looking_for_space = true
            break
          end
        end
      end
    end
    if looking_for_space
      ary.push String.new(buffer + index, len - index)
    end
    ary
  end

  def split(separator : Char, count = -1)
    if separator == ' '
      return split
    end

    ary = Array(String).new
    index = 0
    buffer = cstr
    len = length

    unless count == 1
      len.times do |j|
        if buffer[j] == separator
          ary.push String.new(buffer + index, j - index)
          index = j + 1
          break if ary.length + 1 == count
        end
      end
    end

    if index != len
      ary.push String.new(buffer + index, len - index)
    end

    ary
  end

  def split(separator : String)
    ary = Array(String).new
    index = 0
    buffer = cstr
    separator_length = separator.length

    case separator_length
    when 0
      # Special case: return all chars as strings
      each_char do |c|
        ary.push c.to_s
      end
      return ary
    when 1
      # Another special case: split ignoring empty results
      if separator[0] == ' '
        return split
      end
    end

    i = 0
    stop = length - separator.length + 1
    while i < stop
      if (buffer + i).memcmp(separator.cstr, separator_length)
        ary.push String.new(buffer + index, i - index)
        index = i + separator_length
        i += separator_length - 1
      end
      i += 1
    end
    if index != length
        ary.push String.new(buffer + index, length - index)
    end
    ary
  end

  def lines
    split "\n"
  end

  def length
    @length
  end

  def reverse
    String.new_with_length(length) do |buffer|
      last = length - 1
      length.times do |i|
        buffer[last - i] = cstr[i]
      end
    end
  end

  def each_char
    p = cstr
    length.times do
      yield p.value
      p += 1
    end
  end

  def inspect
    "\"#{dump}\""
  end

  def dump
    replace do |char|
      case char
      when '"'  then "\\\""
      when '\f' then "\\f"
      when '\n' then "\\n"
      when '\r' then "\\r"
      when '\t' then "\\t"
      when '\v' then "\\v"
      when '\0' then "\\0"
      end
    end
  end

  def starts_with?(str : String)
    return false if str.length > length
    C.strncmp(cstr, str, str.length) == 0
  end

  def starts_with?(char : Char)
    @length > 0 && cstr[0] == char
  end

  def ends_with?(str : String)
    return false if str.length > length
    C.strncmp(cstr + length - str.length, str, str.length) == 0
  end

  def ends_with?(char : Char)
    @length > 0 && cstr[@length - 1] == char
  end

  def %(args : Array)
    String.new_from_buffer(length) do |buffer|
      String::Formatter.new(self, args, buffer).format
    end
  end

  def %(other)
    self % [other]
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
    pointerof(@c)
  end
end
