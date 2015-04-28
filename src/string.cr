lib LibC
  fun atoi(str : UInt8*) : Int32
  fun atoll(str : UInt8*) : Int64
  fun atof(str : UInt8*) : Float64
  fun strtof(str : UInt8*, endp : UInt8**) : Float32
  fun strlen(s : UInt8*) : Int32
  fun snprintf(str : UInt8*, n : Int32, format : UInt8*, ...) : Int32
  fun strtol(str : UInt8*, endptr : UInt8**, base : Int32) : Int32
  fun strtoull(str : UInt8*, endptr : UInt8**, base : Int32) : UInt64
end

class String
  # :nodoc:
  TYPE_ID = 1

  # :nodoc:
  HEADER_SIZE = sizeof({Int32, Int32, Int32})

  include Comparable(self)

  # Creates a String form the given slice. Bytes will be copied from the slice.
  #
  # This method is always safe to call, and the resulting string will have
  # the contents and length of the slice.
  #
  # ```
  # slice = Slice.new(4) { |i| ('a'.ord + i).to_u8 }
  # String.new(slice) #=> "abcd"
  # ```
  def self.new(slice : Slice(UInt8))
    new(slice.pointer(slice.length), slice.length)
  end

  # Creates a String from a pointer. Bytes will be copied from the pointer.
  #
  # This method is **unsafe**: the pointer must point to data that eventually
  # contains a zero byte that indicates the ends of the string. Otherwise,
  # the result of this method is undefined and might cause a segmentation fault.
  #
  # This method is typically used in C bindings, where you get a `char*` from a
  # library and the library guarantees that this pointer eventually has an
  # ending zero byte.
  #
  # ```
  # ptr = Pointer.malloc(5) { |i| i == 4 ? 0_u8 : ('a'.ord + i).to_u8 }
  # String.new(ptr) #=> "abcd"
  # ```
  def self.new(chars : UInt8*)
    new(chars, LibC.strlen(chars))
  end

  # Creates a new String from a pointer, indicating its bytesize count
  # and, optionally, the UTF-8 codepoints count (length). Bytes will be
  # copied from the pointer.
  #
  # If the given length is zero, the amount of UTF-8 codepoints will be
  # lazily computed when needed.
  #
  # ```
  # ptr = Pointer.malloc(4) { |i| ('a'.ord + i).to_u8 }
  # String.new(ptr, 2) => "ab"
  # ```
  def self.new(chars : UInt8*, bytesize, length = 0)
    new(bytesize) do |buffer|
      buffer.copy_from(chars, bytesize)
      {bytesize, length}
    end
  end

  # Creates a new String by allocating a buffer (`Pointer(UInt8)`) with the given capacity, then
  # yielding that buffer. The block must return a tuple with the bytesize and length
  # (UTF-8 codepoints count) of the String. If the returned length is zero, the UTF-8 codepoints
  # count will be lazily computed.
  #
  # This method is **unsafe**: the bytesize returned by the block must be less than the
  # capacity given to this String. In the future this method might check that the returned
  # bytesize is less or equal than the capacity, making it a safe method.
  #
  # If you need to build a String where the maximum capacity is unknown, use `String#build`.
  #
  # ```
  # str = String.new(4) do |buffer|
  #   buffer[0] = 'a'.ord.to_u8
  #   buffer[1] = 'b'.ord.to_u8
  #   {2, 2}
  # end
  # str #=> "ab"
  # ```
  def self.new(capacity)
    str = GC.malloc_atomic((capacity + HEADER_SIZE + 1).to_u32) as UInt8*
    buffer = (str as String).cstr
    bytesize, length = yield buffer
    str_header = str as {Int32, Int32, Int32}*
    str_header.value = {TYPE_ID, bytesize.to_i, length.to_i}
    buffer[bytesize] = 0_u8
    str as String
  end

  # Builds a String by creating a `StringIO` with the given initial capacity, yielding
  # it to the block and finally getting a String out of it. The `StringIO` automatically
  # resizes as needed.
  #
  # ```
  # str = String.build do |str|
  #   str << "hello "
  #   str << 1
  # end
  # str #=> "hello 1"
  # ```
  def self.build(capacity = 64)
    builder = StringIO.new(capacity)
    yield builder
    builder.to_s
  end

  # Returns the number of bytes in this string.
  #
  # ```
  # "hello".bytesize         #=> 5
  # "你好".bytesize          #=> 6
  # ```
  def bytesize
    @bytesize
  end

  # Returns the result of interpreting leading characters of this string
  # as a decimal number. Extraneous characters past the end of a valid number are ignored.
  # If there is not a valid number at the start of this string, 0 is returned.
  # This method never raises an exception.
  #
  # ```
  # "12345".to_i             #=> 12345
  # "99 red balloons".to_i   #=> 99
  # "0a".to_i                #=> 0
  # "hello".to_i             #=> 0
  # ```
  def to_i
    LibC.atoi cstr
  end

  # Returns the result of interpreting leading characters in this string as an integer base *base*
  # (between 2 and 36). Extraneous characters past the end of a valid number are ignored.
  # If there is not a valid number at the start of str, 0 is returned.
  # This method never raises an exception when base is valid.
  #
  # ```
  # "0a".to_i(16)            #=> 10
  # "1100101".to_i(2)        #=> 101
  # "1100101".to_i(8)        #=> 294977
  # "1100101".to_i(10)       #=> 1100101
  # "1100101".to_i(16)       #=> 17826049
  # ```
  def to_i(base)
    raise "Invalid base #{base}" unless 2 <= base <= 36

    LibC.strtol(cstr, nil, base)
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
    LibC.atoll cstr
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
    LibC.strtoull(cstr, nil, 10)
  end

  # Returns the result of interpreting leading characters in this string as a floating point number (`Float64`).
  # Extraneous characters past the end of a valid number are ignored. If there is not a valid number at the start of str,
  # 0.0 is returned. This method never raises an exception.
  #
  # ```
  # "123.45e1".to_f        #=> 1234.5
  # "45.67 degrees".to_f   #=> 45.67
  # "thx1138".to_f         #=> 0.0
  # ```
  def to_f
    to_f64
  end

  # Returns the result of interpreting leading characters in this string as a floating point number (`Float32`).
  # Extraneous characters past the end of a valid number are ignored. If there is not a valid number at the start of str,
  # 0.0 is returned. This method never raises an exception.
  #
  # See `#to_f`.
  def to_f32
    LibC.strtof cstr, nil
  end

  # Same as `#to_f`.
  def to_f64
    LibC.atof cstr
  end

  def [](index : Int)
    at(index) { raise IndexOutOfBounds.new }
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
    if single_byte_optimizable?
      return byte_slice(start, count)
    end

    return "" if count <= 0

    start_pos = nil
    end_pos = nil

    reader = CharReader.new(self)
    reader.each_with_index do |char, i|
      if i == start
        start_pos = reader.pos
      elsif i == start + count
        end_pos = reader.pos
      end
    end

    end_pos ||= reader.pos

    if start_pos
      count = end_pos - start_pos
      String.new(count) do |buffer|
        buffer.copy_from(cstr + start_pos, count)
        {count, 0}
      end
    else
      ""
    end
  end

  def []?(index : Int)
    at(index) { nil }
  end

  def []?(str : String)
    includes?(str) ? str : nil
  end

  def []?(regex : Regex)
    self[regex, 0]?
  end

  def []?(regex : Regex, group)
    match = match(regex)
    match[group]? if match
  end

  def [](str : String)
    self[str]?.not_nil!
  end

  def [](regex : Regex)
    self[regex]?.not_nil!
  end

  def [](regex : Regex, group)
    self[regex, group]?.not_nil!
  end

  def at(index : Int)
    at(index) { raise IndexOutOfBounds }
  end

  def at(index : Int)
    if single_byte_optimizable?
      byte = byte_at?(index)
      return byte ? byte.chr : yield
    end

    index += length if index < 0

    each_char_with_index do |char, i|
      if index == i
        return char
      end
    end

    yield
  end

  def byte_slice(start : Int, count : Int)
    return "" if count <= 0

    start += bytesize if start < 0
    count = bytesize - start if start + count > bytesize
    single_byte_optimizable = single_byte_optimizable?

    if 0 <= start < bytesize
      String.new(count) do |buffer|
        buffer.copy_from(cstr + start, count)
        slice_length = single_byte_optimizable ? count : 0
        {count, slice_length}
      end
    else
      ""
    end
  end

  def byte_slice(start : Int)
    byte_slice start, bytesize - start
  end

  def codepoint_at(index)
    char_at(index).ord
  end

  def char_at(index)
    self[index]
  end

  def byte_at(index)
    byte_at(index) { raise IndexOutOfBounds.new }
  end

  def byte_at?(index)
    byte_at(index) { nil }
  end

  def byte_at(index)
    index += bytesize if index < 0
    if 0 <= index < bytesize
      cstr[index]
    else
      yield
    end
  end

  def unsafe_byte_at(index)
    cstr[index]
  end

  def downcase
    String.build(bytesize) do |io|
      each_char do |char|
        io << char.downcase
      end
    end
  end

  def upcase
    String.build(bytesize) do |io|
      each_char do |char|
        io << char.upcase
      end
    end
  end

  def capitalize
    return self if bytesize == 0

    String.build(bytesize) do |io|
      each_char_with_index do |char, i|
        if i == 0
          io << char.upcase
        else
          io << char.downcase
        end
      end
    end
  end

  def chomp
    return self if bytesize == 0

    case cstr[bytesize - 1]
    when '\n'.ord
      if bytesize > 1 && cstr[bytesize - 2] == '\r'.ord
        byte_slice 0, bytesize - 2
      else
        byte_slice 0, bytesize - 1
      end
    when '\r'.ord
      byte_slice 0, bytesize - 1
    else
      self
    end
  end

  def strip
    excess_right = 0
    while cstr[bytesize - 1 - excess_right].chr.whitespace?
      excess_right += 1
    end

    excess_left = 0
    while cstr[excess_left].chr.whitespace?
      excess_left += 1
    end

    if excess_right == 0 && excess_left == 0
      self
    else
      byte_slice excess_left, bytesize - excess_left - excess_right
    end
  end

  def rstrip
    excess_right = 0
    while cstr[bytesize - 1 - excess_right].chr.whitespace?
      excess_right += 1
    end

    if excess_right == 0
      self
    else
      byte_slice 0, bytesize - excess_right
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
      byte_slice excess_left
    end
  end

  def tr(from : String, to : String)
    multi = nil
    table = StaticArray(Int32, 256).new(-1)
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

    String.build(bytesize) do |buffer|
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

  # Returns a new string where each character yielded to the given block
  # is replaced by the block's return value.
  #
  # ```
  # "hello".gsub { |x| (x.ord + 1).chr } #=> "ifmmp"
  # "hello".gsub { "hi" } #=> "hihihihihi"
  # ```
  def gsub(&block : Char -> _)
    String.build(bytesize) do |buffer|
      each_char do |my_char|
        buffer << yield my_char
      end
    end
  end

  # Returns a string where all occurrences of the given char are
  # replaced with the given *replacement*.
  #
  # ```
  # "hello".gsub('l', "lo") #=> "heloloo"
  # "hello world".gsub('o', 'a') #=> "hella warld"
  # ```
  def gsub(char : Char, replacement)
    if includes?(char)
      gsub { |my_char| char == my_char ? replacement : my_char }
    else
      self
    end
  end

  # Returns a string where all occurrences of the given *pattern* are replaced
  # by the block value's value.
  #
  # ```
  # "hello".gsub(/./) {|s| s[0].ord.to_s + ' '} #=> #=> "104 101 108 108 111 "
  # ```
  def gsub(pattern : Regex, &block : String, MatchData -> _)
    byte_offset = 0
    match = pattern.match_at_byte_index(self, byte_offset)
    return self unless match

    String.build(bytesize) do |buffer|
      while match
        index = match.byte_begin(0)

        buffer.write unsafe_byte_slice(byte_offset, index - byte_offset)
        str = match[0]
        buffer << yield str, match
        byte_offset = index + str.bytesize
        match = pattern.match_at_byte_index(self, byte_offset)
      end

      if byte_offset < bytesize
        buffer.write unsafe_byte_slice(byte_offset)
      end
    end
  end

  # Returns a string where all occurrences of the given *pattern* are replaced
  # with the given *replacement*.
  #
  # ```
  # "hello".gsub(/[aeiou]/, '*') #=> "h*ll*"
  # ```
  def gsub(pattern : Regex, replacement)
    gsub(pattern) { replacement }
  end

  # Returns a string where all ocurrences of the given *pattern* are replaced
  # with a *hash* of replacements. If the *hash* contains the matched pattern,
  # the corresponding value is used as a replacement. Otherwise the match is
  # not included in the returned string.
  #
  # ```
  # # "he" and "l" are matched and replaced,
  # # but "o" is not and so is not included
  # "hello".gsub(/(he|l|o)/, {"he": "ha", "l": "la"}).should eq("halala")
  # ```
  def gsub(pattern : Regex, hash : Hash(String, _))
    gsub(pattern) do |match|
      hash[match]?
    end
  end

  # Returns a string where all occurrences of the given *string* are replaced
  # with the given *replacement*.
  #
  # ```
  # "hello yellow".gsub("ll", "dd") #=> "heddo yeddow"
  # ```
  def gsub(string : String, replacement)
    gsub(string) { replacement }
  end

  # Returns a string where all occurrences of the given *string* are replaced
  # with the block's value.
  #
  # ```
  # "hello yellow".gsub("ll") { "dd" } #=> "heddo yeddow"
  # ```
  def gsub(string : String, &block)
    byte_offset = 0
    index = self.byte_index(string, byte_offset)
    return self unless index

    String.build(bytesize) do |buffer|
      while index
        buffer.write unsafe_byte_slice(byte_offset, index - byte_offset)
        buffer << yield string
        byte_offset = index + string.bytesize
        index = self.byte_index(string, byte_offset)
      end
      if byte_offset < bytesize
        buffer.write unsafe_byte_slice(byte_offset)
      end
    end
  end

  # Returns a string where all chars in the given hash are replaced
  # by the corresponding hash values.
  #
  # ```
  # "hello".gsub({'e' => 'a', 'l' => 'd'}) #=> "haddo"
  # ```
  def gsub(hash : Hash(Char, _))
    gsub do |char|
      hash[char]? || char
    end
  end

  # Yields each char in this string to the block,
  # returns the number of times the block returned a truthy value.
  #
  # ```
  # "aabbcc".count {|c| ['a', 'b'].includes?(c) } #=> 4
  # ```
  def count
    count = 0
    each_char do |char|
      count += 1 if yield char
    end
    count
  end

  # Counts the occurrences of other in this string.
  #
  # ```
  # "aabbcc".count('a') #=> 2
  # ```
  def count(other : Char)
    count {|char| char == other }
  end

  # Sets should be a list of strings following the rules
  # described at Char#in_set?. Returns the number of characters
  # in this string that match the given set.
  def count(*sets)
    count {|char| char.in_set?(*sets) }
  end

  # Yields each char in this string to the block.
  # Returns a new string with all characters for which the
  # block returned a truthy value removed.
  #
  # ```
  # "aabbcc".delete {|c| ['a', 'b'].includes?(c) } #=> "cc"
  # ```
  def delete
    String.build(bytesize) do |buffer|
      each_char do |char|
        buffer << char unless yield char
      end
    end
  end

  # Returns a new string with all occurrences of char removed.
  #
  # ```
  # "aabbcc".delete('b') #=> "aacc"
  # ```
  def delete(char : Char)
    delete {|my_char|  my_char == char }
  end

  # Sets should be a list of strings following the rules
  # described at Char#in_set?. Returns a new string with
  # all characters that match the given set removed.
  #
  # ```
  # "aabbccdd".delete("a-c") #=> "dd"
  # ```
  def delete(*sets)
    delete {|char| char.in_set?(*sets) }
  end

  # Yields each char in this string to the block.
  # Returns a new string, that has all characters removed,
  # that were the same as the previous one and for which the given
  # block returned a truthy value.
  #
  # ```
  # "aaabbbccc".squeeze {|c| ['a', 'b'].includes?(c) } #=> "abccc"
  # "aaabbbccc".squeeze {|c| ['a', 'c'].includes?(c) } #=> "abbbc"
  # ```
  def squeeze
    previous = nil
    String.build(bytesize) do |buffer|
      each_char do |char|
        buffer << char unless yield(char) && previous == char
        previous = char
      end
    end
  end

  # Returns a new string, with all runs of char replaced by one instance.
  #
  # ```
  # "a    bbb".squeeze(' ') #=> "a bbb"
  # ```
  def squeeze(char : Char)
    squeeze {|my_char| char == my_char }
  end

  # Sets should be a list of strings following the rules
  # described at Char#in_set?. Returns a new string with all
  # runs of the same character replaced by one instance, if
  # they match the given set.
  #
  # If no set is given, all characters are matched.
  #
  # ```
  # "aaabbbcccddd".squeeze("b-d") #=> "aaabcd"
  # "a       bbb".squeeze #=> "a b"
  # ```
  def squeeze(*sets)
    if sets.empty?
      squeeze { true }
    else
      squeeze {|char| char.in_set?(*sets) }
    end
  end

  def empty?
    bytesize == 0
  end

  def ==(other : self)
    return true if same?(other)
    return false unless bytesize == other.bytesize
    cstr.memcmp(other.cstr, bytesize) == 0
  end

  def <=>(other : self)
    return 0 if same?(other)
    min_bytesize = Math.min(bytesize, other.bytesize)

    cmp = cstr.memcmp(other.cstr, bytesize)
    cmp == 0 ? (bytesize <=> other.bytesize) : cmp
  end

  def =~(regex : Regex)
    match = regex.match(self)
    $~ = match
    match.try &.begin(0)
  end

  def =~(other)
    other =~ self
  end

  def +(other : self)
    size = bytesize + other.bytesize
    String.new(size) do |buffer|
      buffer.copy_from(cstr, bytesize)
      (buffer + bytesize).copy_from(other.cstr, other.bytesize)

      if length_known? && other.length_known?
        {size, @length + other.@length}
      else
        {size, 0}
      end
    end
  end

  def +(char : Char)
    bytes :: UInt8[4]

    count = 0
    char.each_byte do |byte|
      bytes[count] = byte
      count += 1
    end

    size = bytesize + count
    String.new(size) do |buffer|
      buffer.copy_from(cstr, bytesize)
      (buffer + bytesize).copy_from(bytes.buffer, count)

      if length_known?
        {size, @length + 1}
      else
        {size, 0}
      end
    end
  end

  def *(times : Int)
    if times <= 0 || bytesize == 0
      return ""
    elsif bytesize == 1
      return String.new(times) do |buffer|
        Intrinsics.memset(buffer as Void*, cstr[0], times.to_u32, 0_u32, false)
        {times, times}
      end
    end

    total_bytesize = bytesize * times
    String.new(total_bytesize) do |buffer|
      buffer.copy_from(cstr, bytesize)
      n = bytesize

      while n <= total_bytesize / 2
        (buffer + n).copy_from(buffer, n)
        n *= 2
      end

      (buffer + n).copy_from(buffer, total_bytesize - n)
      {total_bytesize, @length * times}
    end
  end

  def index(c : Char, offset = 0)
    offset += length if offset < 0
    return nil if offset < 0

    each_char_with_index do |char, i|
      if i >= offset && char == c
        return i
      end
    end

    nil
  end

  def index(c : String, offset = 0)
    offset += length if offset < 0
    return nil if offset < 0

    end_pos = bytesize - c.bytesize

    reader = CharReader.new(self)
    reader.each_with_index do |char, i|
      if reader.pos <= end_pos
        if i >= offset && (cstr + reader.pos).memcmp(c.cstr, c.bytesize) == 0
          return i
        end
      else
        break
      end
    end

    nil
  end

  def rindex(c : Char, offset = length - 1)
    offset += length if offset < 0
    return nil if offset < 0

    last_index = nil

    each_char_with_index do |char, i|
      if i <= offset && char == c
        last_index = i
      end
    end

    last_index
  end

  def rindex(c : String, offset = length - c.length)
    offset += length if offset < 0
    return nil if offset < 0

    end_length = length - c.length

    last_index = nil

    reader = CharReader.new(self)
    reader.each_with_index do |char, i|
      if i <= end_length && i <= offset && (cstr + reader.pos).memcmp(c.cstr, c.bytesize) == 0
        last_index = i
      end
    end

    last_index
  end

  def byte_index(byte : Int, offset = 0)
    offset.upto(bytesize - 1) do |i|
      if cstr[i] == byte
        return i
      end
    end
    nil
  end

  def byte_index(string : String, offset = 0)
    offset += bytesize if offset < 0
    return nil if offset < 0

    end_pos = bytesize - string.bytesize

    offset.upto(end_pos) do |pos|
      if (cstr + pos).memcmp(string.cstr, string.bytesize) == 0
        return pos
      end
    end

    nil
  end

  # Returns the byte index of a char index, or nil if out of bounds.
  #
  # ```
  # "hello".char_index_to_byte_index(1)     #=> 1
  # "こんにちは".char_index_to_byte_index(1) #=> 3
  # ```
  def char_index_to_byte_index(index)
    reader = CharReader.new(self)
    reader.each_with_index do |char, i|
      if i == index
        return reader.pos
      end
    end
    nil
  end

  def includes?(c : Char)
    !!index(c)
  end

  def includes?(str : String)
    !!index(str)
  end

  def split(limit = nil : Int32?)
    if limit && limit <= 1
      return [self]
    end

    ary = Array(String).new
    single_byte_optimizable = single_byte_optimizable?
    index = 0
    i = 0
    looking_for_space = false
    limit_reached = false
    while i < bytesize
      if looking_for_space
        while i < bytesize
          c = cstr[i]
          i += 1
          if c.chr.whitespace?
            piece_bytesize = i - 1 - index
            piece_length = single_byte_optimizable ? piece_bytesize : 0
            ary.push String.new(cstr + index, piece_bytesize, piece_length)
            looking_for_space = false

            if limit && ary.length + 1 == limit
              limit_reached = true
            end

            break
          end
        end
      else
        while i < bytesize
          c = cstr[i]
          i += 1
          unless c.chr.whitespace?
            index = i - 1
            looking_for_space = true
            break
          end
        end

        break if limit_reached
      end
    end
    if looking_for_space
      piece_bytesize = bytesize - index
      piece_length = single_byte_optimizable ? piece_bytesize : 0
      ary.push String.new(cstr + index, piece_bytesize, piece_length)
    end
    ary
  end

  def split(separator : Char, limit = nil)
    if separator == ' '
      return split(limit)
    end

    if limit && limit <= 1
      return [self]
    end

    ary = Array(String).new

    byte_offset = 0
    single_byte_optimizable = single_byte_optimizable?

    reader = CharReader.new(self)
    reader.each_with_index do |char, i|
      if char == separator
        piece_bytesize = reader.pos - byte_offset
        piece_length = single_byte_optimizable ? piece_bytesize : 0
        ary.push String.new(cstr + byte_offset, piece_bytesize, piece_length)
        byte_offset = reader.pos + reader.current_char_width
        break if limit && ary.length + 1 == limit
      end
    end

    if byte_offset != bytesize
      piece_bytesize = bytesize - byte_offset
      piece_length = single_byte_optimizable ? piece_bytesize : 0
      ary.push String.new(cstr + byte_offset, piece_bytesize, piece_length)
    end

    ary
  end

  def split(separator : String, limit = nil)
    ary = Array(String).new
    byte_offset = 0
    buffer = cstr
    separator_bytesize = separator.bytesize

    if limit && limit <= 1
      return [self]
    end

    if separator.empty?
      # Special case: return all chars as strings
      each_char do |c|
        ary.push c.to_s
        break if limit && ary.length + 1 == limit
      end

      if limit && ary.size != length
        ary.push(self[ary.size..-1])
      end

      return ary
    elsif separator == " "
      # Another special case: split ignoring empty results
      return split(limit)
    end

    single_byte_optimizable = single_byte_optimizable?

    i = 0
    stop = bytesize - separator.bytesize + 1
    while i < stop
      if (buffer + i).memcmp(separator.cstr, separator_bytesize) == 0
        piece_bytesize = i - byte_offset
        piece_length = single_byte_optimizable ? piece_bytesize : 0
        ary.push String.new(cstr + byte_offset, piece_bytesize, piece_length)
        byte_offset = i + separator_bytesize
        i += separator_bytesize - 1
        break if limit && ary.length + 1 == limit
      end
      i += 1
    end
    if byte_offset != bytesize
      piece_bytesize = bytesize - byte_offset
      piece_length = single_byte_optimizable ? piece_bytesize : 0
      ary.push String.new(cstr + byte_offset, piece_bytesize, piece_length)
    end
    ary
  end

  def split(separator : Regex, limit = nil)
    if limit && limit <= 1
      return [self]
    end

    ary = Array(String).new
    match_offset = 0
    slice_offset = 0
    last_slice_offset = 0

    while match = separator.match_at_byte_index(self, match_offset)
      index = match.byte_begin(0)
      slice_length = index - slice_offset
      match_bytesize = match[0].bytesize

      if slice_offset == 0 && slice_length == 0 && match_bytesize == 0
        # Skip
      elsif slice_offset == bytesize && slice_length == 0
        ary.push byte_slice(last_slice_offset)
      else
        ary.push byte_slice(slice_offset, slice_length)
      end

      last_slice_offset = slice_offset

      if match_bytesize == 0
        match_offset = index + 1
        slice_offset = index
      else
        match_offset = index + match_bytesize
        slice_offset = match_offset
      end
      break if limit && ary.length + 1 == limit
      break if slice_offset > bytesize
    end

    if slice_offset < bytesize
      ary.push byte_slice(slice_offset)
    end

    unless limit
      while ary.last?.try &.empty?
        ary.pop
      end
    end

    ary
  end

  def lines
    split "\n"
  end

  def underscore
    first = true
    last_is_downcase = false
    last_is_upcase = false
    mem = nil

    String.build(bytesize + 10) do |str|
      each_char do |char|
        downcase = 'a' <= char <= 'z'
        upcase = 'A' <= char <= 'Z'

        if first
          str << char.downcase
        elsif last_is_downcase && upcase
          # This is the case of AbcDe, we need to put an underscore before the 'D'
          #                        ^
          str << '_'
          str << char.downcase
        elsif last_is_upcase && upcase
          # This is the case of 1) ABCde, 2) ABCDe or 3) ABC_de:if the next char is upcase (case 1) we need
          #                          ^         ^           ^
          # 1) we need to append this char as downcase
          # 2) we need to append an underscore and then the char as downcase, so we save this char
          #    in 'mem' and decide later
          # 3) we need to append this char as downcase and then a single underscore
          if mem
            # case 2
            str << mem.downcase
          end
          mem = char
        else
          if mem
            if char == '_'
              # case 3
              str << mem.downcase
            else
              # case 1
              str << '_'
              str << mem.downcase
            end
            mem = nil
          end
          str << char
        end

        last_is_downcase = downcase
        last_is_upcase = upcase
        first = false
      end
    end
  end

  def camelcase
    first = true
    last_is_underscore = false

    String.build(bytesize) do |str|
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
    String.new(bytesize) do |buffer|
      buffer += bytesize
      reader = CharReader.new(self)
      reader.each do |char|
        buffer -= reader.current_char_width
        i = 0
        char.each_byte do |byte|
          buffer[i] = byte
          i += 1
        end
      end
      {@bytesize, @length}
    end
  end

  def ljust(len, char = ' ' : Char)
    just len, char, true
  end

  def rjust(len, char = ' ' : Char)
    just len, char, false
  end

  private def just(len, char, left)
    return self if length >= len

    bytes :: UInt8[4]

    if char.ord < 0x80
      count = 1
    else
      count = 0
      char.each_byte do |byte|
        bytes[count] = byte
        count += 1
      end
    end

    difference = len - length
    new_bytesize = bytesize + difference * count

    String.new(new_bytesize) do |buffer|
      if left
        buffer.copy_from(cstr, bytesize)
        buffer += bytesize
      end

      if count == 1
        Intrinsics.memset(buffer as Void*, char.ord.to_u8, difference.to_u32, 0_u32, false)
        buffer += difference
      else
        difference.times do
          buffer.copy_from(bytes.buffer, count)
          buffer += count
        end
      end

      unless left
        buffer.copy_from(cstr, bytesize)
      end

      {new_bytesize, len}
    end
  end

  def match(regex : Regex, pos = 0)
    match = regex.match self, pos
    $~ = match
    match
  end

  def scan(pattern : Regex)
    byte_offset = 0

    while match = pattern.match_at_byte_index(self, byte_offset)
      index = match.byte_begin(0)
      yield match
      match_bytesize = match[0].bytesize
      break if match_bytesize == 0
      byte_offset = index + match_bytesize
    end

    self
  end

  def scan(pattern : Regex)
    matches = [] of MatchData
    scan(pattern) do |match|
      matches << match
    end
    matches
  end

  def scan(pattern : String)
    return self if pattern.empty?
    index = 0
    while index = byte_index(pattern, index)
      yield pattern
      index += pattern.bytesize
    end
    self
  end

  def scan(pattern : String)
    matches = [] of String
    scan(pattern) do |match|
      matches << match
    end
    matches
  end

  def each_char
    if single_byte_optimizable?
      each_byte do |byte|
        yield byte.chr
      end
    else
      CharReader.new(self).each do |char|
        yield char
      end
    end
    self
  end

  def each_char
    CharIterator.new(CharReader.new(self))
  end

  def each_char_with_index
    i = 0
    each_char do |char|
      yield char, i
      i += 1
    end
    self
  end

  def chars
    chars = Array(Char).new(@length > 0 ? @length : bytesize)
    each_char do |char|
      chars << char
    end
    chars
  end

  def each_byte
    cstr.to_slice(bytesize).each do |byte|
      yield byte
    end
    self
  end

  def each_byte
    to_slice.each
  end

  def inspect(io)
    dump_or_inspect(io) do |char|
      if char.control?
        io << "\\u{"
        char.ord.to_s(16, io)
        io << "}"
      else
        io << char
      end
    end
  end

  def dump
    String.build do |io|
      dump io
    end
  end

  def dump(io)
    dump_or_inspect(io) do |char|
      if char.control? || char.ord >= 0x80
        io << "\\u{"
        char.ord.to_s(16, io)
        io << "}"
      else
        io << char
      end
    end
  end

  private def dump_or_inspect(io)
    io << "\""
    reader = CharReader.new(self)
    while reader.has_next?
      current_char = reader.current_char
      case current_char
      when '"'  then io << "\\\""
      when '\\' then io << "\\\\"
      when '\b' then io << "\\b"
      when '\e' then io << "\\e"
      when '\f' then io << "\\f"
      when '\n' then io << "\\n"
      when '\r' then io << "\\r"
      when '\t' then io << "\\t"
      when '\v' then io << "\\v"
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
        yield current_char
      end
      reader.next_char
    end
    io << "\""
  end

  def starts_with?(str : String)
    return false if str.bytesize > bytesize
    cstr.memcmp(str.cstr, str.bytesize) == 0
  end

  def starts_with?(char : Char)
    each_char do |c|
      return c == char
    end

    false
  end

  def ends_with?(str : String)
    return false if str.bytesize > bytesize
    (cstr + bytesize - str.bytesize).memcmp(str.cstr, str.bytesize) == 0
  end

  def ends_with?(char : Char)
    return false unless bytesize > 0

    if char.ord < 0x80 || single_byte_optimizable?
      return cstr[bytesize - 1] == char.ord
    end

    bytes :: UInt8[4]

    count = 0
    char.each_byte do |byte|
      bytes[count] = byte
      count += 1
    end

    return false if bytesize < count

    count.times do |i|
      return false unless cstr[bytesize - count + i] == bytes[i]
    end

    true
  end

  def %(other)
    sprintf self, other
  end

  # Return a hash based on this string’s length and content.
  #
  # See also `Object#hash`.
  def hash
    h = 0
    each_byte do |c|
      h = 31 * h + c
    end
    h
  end

  # Returns this string's bytes as an `Array(UInt8)`.
  #
  # ```
  # "hello".bytes          #=> [104, 101, 108, 108, 111]
  # "你好".bytes           #=> [228, 189, 160, 229, 165, 189]
  # ```
  def bytes
    Array.new(bytesize) { |i| cstr[i] }
  end

  # Returns the number of unicode codepoints in this string.
  #
  # ```
  # "hello".length         #=> 5
  # "你好".length          #=> 2
  # ```
  def length
    if @length > 0 || @bytesize == 0
      return @length
    end

    i = 0
    count = 0

    while i < bytesize
      c = cstr[i]
      break if c == 0

      if c < 0x80
        i += 1
      elsif c < 0xe0
        i += 2
      elsif c < 0xf0
        i += 3
      else
        i += 4
      end

      count += 1
    end

    @length = count
  end

  def size
    length
  end

  def ascii_only?
    @bytesize == 0 || length == @bytesize
  end

  protected def single_byte_optimizable?
    @bytesize == @length
  end

  protected def length_known?
    @bytesize == 0 || @length > 0
  end

  def to_slice
    Slice.new(cstr, bytesize)
  end

  def to_s
    self
  end

  def to_s(io)
    io.write Slice.new(cstr, bytesize)
  end

  def cstr
    pointerof(@c)
  end

  def to_unsafe
    cstr
  end

  def unsafe_byte_slice(byte_offset, count)
    Slice.new(cstr + byte_offset, count)
  end

  def unsafe_byte_slice(byte_offset)
    Slice.new(cstr + byte_offset, bytesize - byte_offset)
  end

  class CharIterator
    include Iterator(Char)

    def initialize(@reader, @end = false)
    end

    def next
      return stop if @end

      value = @reader.current_char
      @reader.next_char
      @end = true unless @reader.has_next?

      value
    end

    def rewind
      @reader.pos = 0
      @end = false
      self
    end
  end
end

require "./string/formatter"
