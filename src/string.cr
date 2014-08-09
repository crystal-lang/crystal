lib C
  fun atoi(str : UInt8*) : Int32
  fun atoll(str : UInt8*) : Int64
  fun atof(str : UInt8*) : Float64
  fun strtof(str : UInt8*, endp : UInt8**) : Float32
  fun strlen(s : UInt8*) : Int32
  fun sprintf(str : UInt8*, format : UInt8*, ...) : Int32
  fun strtol(str : UInt8*, endptr : UInt8**, base : Int32) : Int32
  fun strtoul(str : UInt8*, endptr : UInt8**, base : Int32) : UInt64
end

class String
  include Comparable(self)

  getter length

  def self.new(slice : Slice(UInt8))
    new(slice.pointer(slice.length), slice.length)
  end

  def self.new(chars : UInt8*)
    new(chars, C.strlen(chars))
  end

  def self.new(chars : UInt8*, length)
    str = GC.malloc_atomic((length + 9).to_u32) as UInt8*
    (str as Int32*).value = "".crystal_type_id
    ((str as Int32*) + 1).value = length
    ((str as UInt8*) + 8).copy_from(chars, length)
    ((str + length + 8) as UInt8*).value = 0_u8
    str as String
  end

  def self.new_and_free(chars : UInt8*)
    str = new(chars, C.strlen(chars))
    C.free(chars as Void*)
    str
  end

  def self.new_with_capacity(capacity)
    new_with_capacity_and_length(capacity) do |buffer|
      yield buffer
      C.strlen(buffer)
    end
  end

  def self.new_with_capacity_and_length(capacity)
    str = GC.malloc_atomic((capacity + 9).to_u32) as UInt8*
    buffer = (str as String).cstr
    length = yield buffer
    buffer[length] = 0_u8
    (str as Int32*).value = "".crystal_type_id
    ((str as Int32*) + 1).value = length
    str as String
  end

  def self.new_with_length(length)
    str = GC.malloc_atomic((length + 9).to_u32) as UInt8*
    buffer = (str as String).cstr
    yield buffer
    buffer[length] = 0_u8
    (str as Int32*).value = "".crystal_type_id
    ((str as Int32*) + 1).value = length
    str as String
  end

  def self.build(capacity = 64)
    builder = StringIO.new(capacity)
    yield builder
    builder.to_s
  end

  def to_i
    C.atoi cstr
  end

  def to_i(base)
    C.strtol(cstr, nil, base)
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
    C.strtoul(cstr, nil, 10)
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
      buffer.copy_from(cstr + start, count)
    end
  end

  def codepoint_at(index)
    char_at(index).ord
  end

  def char_at(index)
    i = 0
    each_char do |char|
      if i == index
        return char
      end
      i += 1
    end

    raise IndexOutOfBounds.new
  end

  def downcase
    String.new_with_length(length) do |buffer|
      length.times do |i|
        buffer[i] = cstr[i].chr.downcase.ord.to_u8
      end
    end
  end

  def upcase
    String.new_with_length(length) do |buffer|
      length.times do |i|
        buffer[i] = cstr[i].chr.upcase.ord.to_u8
      end
    end
  end

  def capitalize
    return self if length == 0

    String.new_with_length(length) do |buffer|
      buffer[0] = cstr[0].chr.upcase.ord.to_u8
      (length - 1).times do |i|
        buffer[i + 1] = cstr[i + 1].chr.downcase.ord.to_u8
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
    while cstr[length - 1 - excess_right].chr.whitespace?
      excess_right += 1
    end

    excess_left = 0
    while cstr[excess_left].chr.whitespace?
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
    while cstr[length - 1 - excess_right].chr.whitespace?
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
    while cstr[excess_left].chr.whitespace?
      excess_left += 1
    end

    if excess_left == 0
      self
    else
      self[excess_left, length - excess_left]
    end
  end

  def tr(from : String, to : String)
    multi = nil
    table :: Int32[256]
    256.times { |i| table[i] = -1 }
    reader = CharReader.new(to)
    char = reader.current_char
    next_char = reader.next_char
    from.each_char do |ch|
      if ch.ord >= 256
        multi ||= {} of Char => Char
        multi[ch] = char
      else
        table[ch.ord] = char.ord
      end
      if next_char != Char::ZERO
        char = next_char
        reader.next_char
        next_char = reader.current_char
      end
    end

    String.build(length) do |buffer|
      each_char do |ch|
        if ch.ord < 256
          if (a = table[ch.ord]) >= 0
            buffer << a.chr
          else
            buffer << ch
          end
        else
          if a = multi.try &.[ch]?
            buffer << a
          else
            buffer << ch
          end
        end
      end
    end
  end

  def replace(&block : Char -> String)
    String.build(length) do |buffer|
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
    if includes?(char)
      replace { |my_char| char == my_char ? replacement : nil }
    else
      self
    end
  end

  def replace(char : Char, replacement : Char)
    if includes?(char)
      replace(char, replacement.to_s)
    else
      self
    end
  end

  def replace(pattern : Regex)
    len = length
    offset = 0
    buffer = StringIO.new(len)
    while true
      match = pattern.match(self, offset)
      if match
        index = match.begin(0)
        if index > offset
          offset.upto(index - 1) do |i|
            buffer.write_byte cstr[i]
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
        buffer.write_byte cstr[i]
      end
    end

    buffer.to_s
  end

  def replace(pattern : Regex, replacement : String)
    replace(pattern) { replacement }
  end

  def delete(char : Char)
    String.build(length) do |buffer|
      each_char do |my_char|
        buffer << my_char unless my_char == char
      end
    end
  end

  def empty?
    @length == 0
  end

  def ==(other : self)
    return true if same?(other)
    return false unless length == other.length
    cstr.memcmp(other.cstr, length)
  end

  def <=>(other : self)
    return 0 if same?(other)
    min_length = Math.min(length, other.length)
    cmp = C.memcmp(cstr as Void*, other.cstr as Void*, length.to_sizet)
    cmp == 0 ? (length <=> other.length) : cmp
  end

  def =~(regex : Regex)
    match = regex.match(self)
    match ? match.begin(0) : nil
  end

  def =~(other)
    nil
  end

  def +(other : self)
    String.new_with_length(length + other.length) do |buffer|
      buffer.copy_from(cstr, length)
      (buffer + length).copy_from(other.cstr, other.length)
    end
  end

  def *(times : Int)
    if times <= 0 || length == 0
      return ""
    elsif length == 1
      return String.new_with_length(times) do |buffer|
        Intrinsics.memset(buffer as Void*, cstr[0], times.to_u32, 0_u32, false)
      end
    end

    total_length = length * times
    String.new_with_length(total_length) do |buffer|
      buffer.copy_from(cstr, length)
      n = length

      while n <= total_length / 2
        (buffer + n).copy_from(buffer, n)
        n *= 2
      end

      (buffer + n).copy_from(buffer, total_length - n)
    end
  end

  def index(c : Char, offset = 0)
    offset += length if offset < 0
    return nil if offset < 0

    while offset < length
      return offset if cstr[offset] == c
      offset += 1
    end
    nil
  end

  def index(c : String, offset = 0)
    offset += length if offset < 0
    return nil if offset < 0

    end_length = length - c.length
    while offset <= end_length
      return offset if (cstr + offset).memcmp(c.cstr, c.length)
      offset += 1
    end
    nil
  end

  def rindex(c : Char, offset = length - 1)
    offset += length if offset < 0
    return nil if offset < 0

    while offset >= 0
      return offset if cstr[offset] == c
      offset -= 1
    end
    nil
  end

  def rindex(c : String, offset = length - c.length)
    offset += length if offset < 0
    return nil if offset < 0

    offset = length - c.length if offset > length - c.length
    while offset >= 0
      return offset if (cstr + offset).memcmp(c.cstr, c.length)
      offset -= 1
    end
    nil
  end

  def includes?(c : Char)
    !!index(c)
  end

  def includes?(str : String)
    !!index(str)
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
          if c.chr.whitespace?
            ary.push String.new(buffer + index, i - 1 - index)
            looking_for_space = false
            break
          end
        end
      else
        while i < len
          c = buffer[i]
          i += 1
          unless c.chr.whitespace?
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

  def split(separator : Char, limit = -1)
    if separator == ' '
      return split
    end

    ary = Array(String).new
    index = 0
    buffer = cstr
    len = length

    unless limit == 1
      len.times do |j|
        if buffer[j] == separator
          ary.push String.new(buffer + index, j - index)
          index = j + 1
          break if ary.length + 1 == limit
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

  def underscore
    first = true
    last_is_downcase = false

    String.build(length + 10) do |str|
      each_char do |char|
        downcase = 'a' <= char <= 'z'
        upcase = 'A' <= char <= 'Z'

        if first
          str << char.downcase
        elsif last_is_downcase && upcase
          str << '_'
          str << char.downcase
        else
          str << char
        end

        last_is_downcase = downcase
        first = false
      end
    end
  end

  def camelcase
    first = true
    last_is_underscore = false

    String.build(length) do |str|
      each_char do |char|
        if first
          str << char.upcase
        elsif char == '_'
          last_is_underscore = true
        elsif last_is_underscore
          str << char.upcase
          last_is_underscore = false
        else
          str << char
        end
        first = false
      end
    end
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
    reader = CharReader.new(self)
    reader.each do |char|
      yield char
    end
    self
  end

  def each_byte
    cstr.as_enumerable(length).each do |byte|
      yield byte
    end
    self
  end

  def inspect(io)
    io << "\""
    dump io
    io << "\""
  end

  def dump
    String.build do |io|
      dump io
    end
  end

  def dump(io)
    reader = CharReader.new(self)
    while reader.has_next?
      current_char = reader.current_char
      case current_char
      when '"'  then io << "\\\""
      when '\f' then io << "\\f"
      when '\n' then io << "\\n"
      when '\r' then io << "\\r"
      when '\t' then io << "\\t"
      when '\v' then io << "\\v"
      when '\e' then io << "\\e"
      when '\\' then io << "\\\\"
      when '#'
        current_char = reader.next_char
        if current_char == '{'
          io << "\\\#{"
          reader.next_char
          next
        else
          io << '#'
          next
        end
      else
        ord = current_char.ord
        if ord < 32 || ord > 127
          high = ord / 16
          low = ord % 16
          high = high < 10 ? ('0'.ord + high).chr : ('A'.ord + high - 10).chr
          low = low < 10 ? ('0'.ord + low).chr : ('A'.ord + low - 10).chr
          io << "\\x"
          io << high
          io << low
        else
          io << current_char
        end
      end
      reader.next_char
    end
  end

  def starts_with?(str : String)
    return false if str.length > length
    C.memcmp(cstr as Void*, str.cstr as Void*, str.length.to_sizet) == 0
  end

  def starts_with?(char : Char)
    @length > 0 && cstr[0] == char
  end

  def ends_with?(str : String)
    return false if str.length > length
    C.memcmp((cstr + length - str.length) as Void*, str.cstr as Void*, str.length.to_sizet) == 0
  end

  def ends_with?(char : Char)
    @length > 0 && cstr[@length - 1] == char
  end

  def %(args : Array)
    String.build(length) do |buffer|
      String::Formatter.new(self, args, buffer).format
    end
  end

  def %(other)
    self % [other]
  end

  def hash
    h = 0
    each_byte do |c|
      h = 31 * h + c
    end
    h
  end

  def to_s
    self
  end

  def to_s(io)
    io.write Slice.new(cstr, @length)
  end

  def cstr
    pointerof(@c)
  end

  def to_unsafe
    cstr
  end
end

require "string/formatter"
