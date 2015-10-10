lib LibC
  fun atof(str : Char*) : Double
  fun strtof(str : Char*, endp : Char**) : Float
  fun strlen(s : Char*) : SizeT
  fun snprintf(str : Char*, n : SizeT, format : Char*, ...) : Int
  fun strcmp(Char*, Char*) : LibC::Int
end

# A String represents an immutable sequence of UTF-8 characters.
#
# A String is typically created with a string literal, enclosing UTF-8 characters
# in double quotes:
#
# ```
# "hello world"
# ```
#
# A backslash can be used to denote some characters inside the string:
#
# ```
# "\"" # double quote
# "\\" # backslash
# "\e" # escape
# "\f" # form feed
# "\n" # newline
# "\r" # carriage return
# "\t" # tab
# "\v" # vertical tab
# ```
#
# You can use a backslash followed by at most three digits to denote a code point written in octal:
#
# ```text
# "\101" # == "A"
# "\123" # == "S"
# "\12"  # == "\n"
# "\1"   # string with one character with code point 1
# ```
#
# You can use a backslash followed by an *u* and four hexadecimal characters to denote a unicode codepoint written:
#
# ```text
# "\u0041" # == "A"
# ```
#
# Or you can use curly braces and specify up to six hexadecimal numbers (0 to 10FFFF):
#
# ```text
# "\u{41}" # == "A"
# ```
#
# A string can span multiple lines:
#
# ```text
# "hello
#       world" # same as "hello      \nworld"
# ```
#
# Note that in the above example trailing and leading spaces, as well as newlines,
# end up in the resulting string. To avoid this, you can split a string into multiple lines
# by joining multiple literals with a backslash:
#
# ```text
# "hello " \
# "world, " \
# "no newlines" # same as "hello world, no newlines"
# ```
#
# Alterantively, a backlash followed by a newline can be inserted inside the string literal:
#
# ```text
# "hello \
#      world, \
#      no newlines" # same as "hello world, no newlines"
# ```
#
# In this case, leading whitespace is not included in the resulting string.
#
# If you need to write a string that has many double quotes, parenthesis, or similar
# characters, you can use alternative literals:
#
# ```text
# # Supports double quotes and nested parenthesis
# %(hello ("world")) # same as "hello (\"world\")"
#
# # Supports double quotes and nested brackets
# %[hello ["world"]] # same as "hello [\"world\"]"
#
# # Supports double quotes and nested curlies
# %{hello {"world"}} # same as "hello {\"world\"}"
#
# # Supports double quotes and nested angles
# %<hello <"world">> # same as "hello <\"world\">"
# ```
#
# To create a String with embedded expressions, you can use string interpolation:
#
# ```
# a = 1
# b = 2
# "sum = #{a + b}"        # "sum = 3"
# ```
#
# This ends up invoking `Object#to_s(IO)` on each expression enclosed by `#{...}`.
#
# If you need to dynamically build a string, use `String#build` or `StringIO`.
class String
  # :nodoc:
  TYPE_ID = 1

  # :nodoc:
  HEADER_SIZE = sizeof({Int32, Int32, Int32})

  include Comparable(self)

  # Creates a String form the given slice. Bytes will be copied from the slice.
  #
  # This method is always safe to call, and the resulting string will have
  # the contents and size of the slice.
  #
  # ```
  # slice = Slice.new(4) { |i| ('a'.ord + i).to_u8 }
  # String.new(slice) #=> "abcd"
  # ```
  #
  # Note: if the slice doesn't denote a valid UTF-8 sequence, this method still succeeds.
  # However, when iterating it or indexing it, an `InvalidByteSequenceError` will be raised.
  def self.new(slice : Slice(UInt8))
    new(slice.pointer(slice.size), slice.size)
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
  #
  # Note: if the chars don't denote a valid UTF-8 sequence, this method still succeeds.
  # However, when iterating it or indexing it, an `InvalidByteSequenceError` will be raised.
  def self.new(chars : UInt8*)
    new(chars, LibC.strlen(chars))
  end

  # Creates a new String from a pointer, indicating its bytesize count
  # and, optionally, the UTF-8 codepoints count (size). Bytes will be
  # copied from the pointer.
  #
  # If the given size is zero, the amount of UTF-8 codepoints will be
  # lazily computed when needed.
  #
  # ```
  # ptr = Pointer.malloc(4) { |i| ('a'.ord + i).to_u8 }
  # String.new(ptr, 2) => "ab"
  # ```
  #
  # Note: if the chars don't denote a valid UTF-8 sequence, this method still succeeds.
  # However, when iterating it or indexing it, an `InvalidByteSequenceError` will be raised.
  def self.new(chars : UInt8*, bytesize, size = 0)
    new(bytesize) do |buffer|
      buffer.copy_from(chars, bytesize)
      {bytesize, size}
    end
  end

  # Creates a new String by allocating a buffer (`Pointer(UInt8)`) with the given capacity, then
  # yielding that buffer. The block must return a tuple with the bytesize and size
  # (UTF-8 codepoints count) of the String. If the returned size is zero, the UTF-8 codepoints
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
  #
  # Note: if the buffer doesn't end up denoting a valid UTF-8 sequence, this method still succeeds.
  # However, when iterating it or indexing it, an `InvalidByteSequenceError` will be raised.
  def self.new(capacity : Int)
    check_capacity_in_bounds(capacity)

    str = GC.malloc_atomic((capacity + HEADER_SIZE + 1).to_u32) as UInt8*
    buffer = (str as String).cstr
    bytesize, size = yield buffer
    str_header = str as {Int32, Int32, Int32}*
    str_header.value = {TYPE_ID, bytesize.to_i, size.to_i}
    buffer[bytesize] = 0_u8
    str as String
  end

  # Builds a String by creating a `String::Builder` with the given initial capacity, yielding
  # it to the block and finally getting a String out of it. The `String::Builder` automatically
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
    String::Builder.build(capacity) do |builder|
      yield builder
    end
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

  # Returns the result of interpreting leading characters in this string as an
  # integer base *base* (between 2 and 36).
  #
  # If there is not a valid number at the start of this string,
  # or if the resulting integer doesn't fit an Int32, an ArgumentError is raised.
  #
  # Options:
  # * **whitespace**: if true, leading and trailing whitespaces are allowed
  # * **underscore**: if true, underscores in numbers are allowed
  # * **prefix**: if true, the prefixes "0x", "0" and "0b" override the base
  # * **strict**: if true, extraneous characters past the end of the number are disallowed
  #
  # ```
  # "12345".to_i                             #=> 12345
  # "0a".to_i                                #=> 0
  # "hello".to_i                             #=> raises
  # "0a".to_i(16)                            #=> 10
  # "1100101".to_i(2)                        #=> 101
  # "1100101".to_i(8)                        #=> 294977
  # "1100101".to_i(10)                       #=> 1100101
  # "1100101".to_i(base: 16)                 #=> 17826049
  #
  # "12_345".to_i                            #=> raises
  # "12_345".to_i(underscore: true)          #=> 12345
  #
  # "  12345  ".to_i                         #=> 12345
  # "  12345  ".to_i(whitepsace: false)      #=> raises
  #
  # "0x123abc".to_i                          #=> raises
  # "0x123abc".to_i(prefix: true)            #=> 1194684
  #
  # "99 red balloons".to_i                   #=> raises
  # "99 red balloons".to_i(strict: false)    #=> 99
  # ```
  def to_i(base = 10, whitespace = true, underscore = false, prefix = false, strict = true)
    to_i32(base, whitespace, underscore, prefix, strict)
  end

  # Same as `#to_i`, but returns `nil` if there is not a valid number at the start
  # of this string, or if the resulting integer doesn't fit an Int32.
  #
  # ```
  # "12345".to_i?            #=> 12345
  # "99 red balloons".to_i?  #=> 99
  # "0a".to_i?               #=> 0
  # "hello".to_i?            #=> nil
  # ```
  def to_i?(base = 10, whitespace = true, underscore = false, prefix = false, strict = true)
    to_i32?(base, whitespace, underscore, prefix, strict)
  end

  # Same as `#to_i`, but returns the block's value if there is not a valid number at the start
  # of this string, or if the resulting integer doesn't fit an Int32.
  #
  # ```
  # "12345".to_i { 0 }       #=> 12345
  # "hello".to_i { 0 }       #=> 0
  # ```
  def to_i(base = 10, whitespace = true, underscore = false, prefix = false, strict = true, &block)
    to_i32(base, whitespace, underscore, prefix, strict) { yield }
  end

  # Same as `#to_i` but returns an Int8.
  def to_i8(base = 10, whitespace = true, underscore = false, prefix = false, strict = true) : Int8
    to_i8(base, whitespace, underscore, prefix, strict) { raise ArgumentError.new("invalid Int8: #{self}") }
  end

  # Same as `#to_i` but returns an Int8 or nil.
  def to_i8?(base = 10, whitespace = true, underscore = false, prefix = false, strict = true) : Int8?
    to_i8(base, whitespace, underscore, prefix, strict) { nil }
  end

  # Same as `#to_i` but returns an Int8 or the block's value.
  def to_i8(base = 10, whitespace = true, underscore = false, prefix = false, strict = true, &block)
    gen_to_ i8, 127, 128
  end

  # Same as `#to_i` but returns an UInt8.
  def to_u8(base = 10, whitespace = true, underscore = false, prefix = false, strict = true) : UInt8
    to_u8(base, whitespace, underscore, prefix, strict) { raise ArgumentError.new("invalid UInt8: #{self}") }
  end

  # Same as `#to_i` but returns an UInt8 or nil.
  def to_u8?(base = 10, whitespace = true, underscore = false, prefix = false, strict = true) : UInt8?
    to_u8(base, whitespace, underscore, prefix, strict) { nil }
  end

  # Same as `#to_i` but returns an UInt8 or the block's value.
  def to_u8(base = 10, whitespace = true, underscore = false, prefix = false, strict = true, &block)
    gen_to_ u8, 255
  end

  # Same as `#to_i` but returns an Int16.
  def to_i16(base = 10, whitespace = true, underscore = false, prefix = false, strict = true) : Int16
    to_i16(base, whitespace, underscore, prefix, strict) { raise ArgumentError.new("invalid Int16: #{self}") }
  end

  # Same as `#to_i` but returns an Int16 or nil.
  def to_i16?(base = 10, whitespace = true, underscore = false, prefix = false, strict = true) : Int16?
    to_i16(base, whitespace, underscore, prefix, strict) { nil }
  end

  # Same as `#to_i` but returns an Int16 or the block's value.
  def to_i16(base = 10, whitespace = true, underscore = false, prefix = false, strict = true, &block)
    gen_to_ i16, 32767, 32768
  end

  # Same as `#to_i` but returns an UInt16.
  def to_u16(base = 10, whitespace = true, underscore = false, prefix = false, strict = true) : UInt16
    to_u16(base, whitespace, underscore, prefix, strict) { raise ArgumentError.new("invalid UInt16: #{self}") }
  end

  # Same as `#to_i` but returns an UInt16 or nil.
  def to_u16?(base = 10, whitespace = true, underscore = false, prefix = false, strict = true) : UInt16?
    to_u16(base, whitespace, underscore, prefix, strict) { nil }
  end

  # Same as `#to_i` but returns an UInt16 or the block's value.
  def to_u16(base = 10, whitespace = true, underscore = false, prefix = false, strict = true, &block)
    gen_to_ u16, 65535
  end

  # Same as `#to_i`.
  def to_i32(base = 10, whitespace = true, underscore = false, prefix = false, strict = true) : Int32
    to_i32(base, whitespace, underscore, prefix, strict) { raise ArgumentError.new("invalid Int32: #{self}") }
  end

  # Same as `#to_i`.
  def to_i32?(base = 10, whitespace = true, underscore = false, prefix = false, strict = true) : Int32?
    to_i32(base, whitespace, underscore, prefix, strict) { nil }
  end

  # Same as `#to_i`.
  def to_i32(base = 10, whitespace = true, underscore = false, prefix = false, strict = true, &block)
    gen_to_ i32, 2147483647, 2147483648
  end

  # Same as `#to_i` but returns an UInt32.
  def to_u32(base = 10, whitespace = true, underscore = false, prefix = false, strict = true) : UInt32
    to_u32(base, whitespace, underscore, prefix, strict) { raise ArgumentError.new("invalid UInt32: #{self}") }
  end

  # Same as `#to_i` but returns an UInt32 or nil.
  def to_u32?(base = 10, whitespace = true, underscore = false, prefix = false, strict = true) : UInt32?
    to_u32(base, whitespace, underscore, prefix, strict) { nil }
  end

  # Same as `#to_i` but returns an UInt32 or the block's value.
  def to_u32(base = 10, whitespace = true, underscore = false, prefix = false, strict = true, &block)
    gen_to_ u32, 4294967295
  end

  # Same as `#to_i` but returns an Int64.
  def to_i64(base = 10, whitespace = true, underscore = false, prefix = false, strict = true) : Int64
    to_i64(base, whitespace, underscore, prefix, strict) { raise ArgumentError.new("invalid Int64: #{self}") }
  end

  # Same as `#to_i` but returns an Int64 or nil.
  def to_i64?(base = 10, whitespace = true, underscore = false, prefix = false, strict = true) : Int64?
    to_i64(base, whitespace, underscore, prefix, strict) { nil }
  end

  # Same as `#to_i` but returns an Int64 or the block's value.
  def to_i64(base = 10, whitespace = true, underscore = false, prefix = false, strict = true, &block)
    gen_to_ i64, 9223372036854775807, 9223372036854775808
  end

  # Same as `#to_i` but returns an UInt64.
  def to_u64(base = 10, whitespace = true, underscore = false, prefix = false, strict = true) : UInt64
    to_u64(base, whitespace, underscore, prefix, strict) { raise ArgumentError.new("invalid UInt64: #{self}") }
  end

  # Same as `#to_i` but returns an UInt64 or nil.
  def to_u64?(base = 10, whitespace = true, underscore = false, prefix = false, strict = true) : UInt64?
    to_u64(base, whitespace, underscore, prefix, strict) { nil }
  end

  # Same as `#to_i` but returns an UInt64 or the block's value.
  def to_u64(base = 10, whitespace = true, underscore = false, prefix = false, strict = true, &block)
    gen_to_ u64
  end

  # :nodoc:
  CHAR_TO_DIGIT = begin
    table = StaticArray(Int8, 256).new(-1_i8)
    10_i8.times do |i|
      table.to_unsafe[48 + i] = i
    end
    26_i8.times do |i|
      table.to_unsafe[65 + i] = i + 10
      table.to_unsafe[97 + i] = i + 10
    end
    table
  end

  # :nodoc:
  record ToU64Info, value, negative, invalid

  # :nodoc
  macro gen_to_(method, max_positive = nil, max_negative = nil)
    info = to_u64_info(base, whitespace, underscore, prefix, strict)
    return yield if info.invalid

    if info.negative
      {% if max_negative %}
        return yield if info.value > {{max_negative}}
        -info.value.to_{{method}}
      {% else %}
        return yield
      {% end %}
    else
      {% if max_positive %}
        return yield if info.value > {{max_positive}}
      {% end %}
      info.value.to_{{method}}
    end
  end

  private def to_u64_info(base, whitespace, underscore, prefix, strict)
    raise ArgumentError.new "invalid base #{base}" unless 2 <= base <= 36

    ptr = cstr

    # Skip leading whitespace
    if whitespace
      while ptr.value.chr.whitespace?
        ptr += 1
      end
    end

    negative = false
    found_digit = false
    mul_overflow = ~0_u64 / base

    # Check + and -
    case ptr.value.chr
    when '+'
      ptr += 1
    when '-'
      negative = true
      ptr += 1
    end

    # Check leading zero
    if ptr.value.chr == '0'
      ptr += 1

      if prefix
        case ptr.value.chr
        when 'b'
          base = 2
          ptr += 1
        when 'x'
          base = 16
          ptr += 1
        else
          base = 8
        end
        found_digit = false
      else
        found_digit = true
      end
    end

    value = 0_u64
    last_is_underscore = true
    invalid = false

    digits = CHAR_TO_DIGIT.to_unsafe
    while ptr.value != 0
      if ptr.value.chr == '_' && underscore
        break if last_is_underscore
        last_is_underscore = true
        ptr += 1
        next
      end

      last_is_underscore = false
      digit = digits[ptr.value]
      if digit == -1 || digit >= base
        break
      end

      if value > mul_overflow
        invalid = true
        break
      end

      value *= base

      old = value
      value += digit
      if value < old
        invalid = true
        break
      end

      found_digit = true
      ptr += 1
    end

    if found_digit
      unless ptr.value == 0
        if whitespace
          while ptr.value.chr.whitespace?
            ptr += 1
          end
        end

        if strict && ptr.value != 0
          invalid = true
        end
      end
    else
      invalid = true
    end

    ToU64Info.new value, negative, invalid
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

  # Returns the `Char` at the give index, or raises `IndexError` if out of bounds.
  #
  # Negative indices can be used to start counting from the end of the string.
  #
  # ```
  # "hello"[0]  # 'h'
  # "hello"[1]  # 'e'
  # "hello"[-1] # 'o'
  # "hello"[-2] # 'l'
  # "hello"[5]  # raises IndexError
  # ```
  def [](index : Int)
    at(index) { raise IndexError.new }
  end

  # Returns a substring by using a Range's *begin* and *end*
  # as character indices. Indices can be negative to start
  # counting from the end of the string.
  #
  # Raises `IndexError` if the range's start is not in range.
  #
  # ```
  # "hello"[0..2]  # "hel"
  # "hello"[0...2] # "he"
  # "hello"[1..-1]  # "ello"
  # "hello"[1...-1]  # "ell"
  # ```
  def [](range : Range(Int, Int))
    from = range.begin
    from += size if from < 0
    raise IndexError.new if from < 0

    to = range.end
    to += size if to < 0
    to -= 1 if range.excludes_end?
    size = to - from + 1
    size = 0 if size < 0
    self[from, size]
  end

  # Returns a substring starting from the `start` character
  # of size `count`.
  #
  # The `start` argument can be negative to start counting
  # from the end of the string.
  #
  # Raises `IndexError` if `start` isn't in range.
  #
  # Raises `ArgumentError` if `count` is negative.
  def [](start : Int, count : Int)
    if single_byte_optimizable?
      return byte_slice(start, count)
    end

    start += size if start < 0

    start_pos = nil
    end_pos = nil

    reader = Char::Reader.new(self)
    i = 0

    reader.each_with_index do |char|
      if i == start
        start_pos = reader.pos
      elsif count >= 0 && i == start + count
        end_pos = reader.pos
        i += 1
        break
      end
      i += 1
    end

    end_pos ||= reader.pos

    if start_pos
      raise ArgumentError.new "negative count" if count < 0
      return "" if count == 0

      count = end_pos - start_pos
      String.new(count) do |buffer|
        buffer.copy_from(cstr + start_pos, count)
        {count, 0}
      end
    elsif start == i
      if count >= 0
        return ""
      else
        raise ArgumentError.new "negative count"
      end
    else
      raise IndexError.new
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
    at(index) { raise IndexError }
  end

  def at(index : Int)
    if single_byte_optimizable?
      byte = byte_at?(index)
      return byte ? byte.chr : yield
    end

    index += size if index < 0

    each_char_with_index do |char, i|
      if index == i
        return char
      end
    end

    yield
  end

  def byte_slice(start : Int, count : Int)
    start += bytesize if start < 0
    single_byte_optimizable = single_byte_optimizable?

    if 0 <= start < bytesize
      raise ArgumentError.new "negative count" if count < 0

      count = bytesize - start if start + count > bytesize
      return "" if count == 0

      String.new(count) do |buffer|
        buffer.copy_from(cstr + start, count)
        slice_size = single_byte_optimizable ? count : 0
        {count, slice_size}
      end
    elsif start == bytesize
      if count >= 0
        return ""
      else
        raise ArgumentError.new "negative count"
      end
    else
      raise IndexError.new
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
    byte_at(index) { raise IndexError.new }
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
    when '\n'
      if bytesize > 1 && cstr[bytesize - 2] === '\r'
        byte_slice 0, bytesize - 2
      else
        byte_slice 0, bytesize - 1
      end
    when '\r'
      byte_slice 0, bytesize - 1
    else
      self
    end
  end

  def chomp(char : Char)
    if ends_with?(char)
      count = 0
      char.each_byte do |byte|
        count += 1
      end
      String.new(unsafe_byte_slice(0, bytesize - count))
    else
      self
    end
  end

  def chomp(string : String)
    if string.empty?
      return self if empty?

      pos = bytesize - 1
      while pos > 0 && cstr[pos] === '\n'
        if pos > 1 && cstr[pos - 1] === '\r'
          pos -= 2
        else
          pos -= 1
        end
      end
      String.new(unsafe_byte_slice(0, pos + 1))
    elsif ends_with?(string)
      String.new(unsafe_byte_slice(0, bytesize - string.bytesize))
    else
      self
    end
  end

  # Returns a new String with the last character removed.
  # If the string ends with `\r\n`, both characters are removed.
  # Applying chop to an empty string returns an empty string.
  #
  # ```
  # "string\r\n".chop   #=> "string"
  # "string\n\r".chop   #=> "string\n"
  # "string\n".chop     #=> "string"
  # "string".chop       #=> "strin"
  # "x".chop.chop       #=> ""
  # ```
  #
  # See also: `#chomp`
  def chop
    return "" if bytesize <= 1

    if bytesize >= 2 && cstr[bytesize - 1] === '\n' && cstr[bytesize - 2] === '\r'
      return byte_slice(0, bytesize - 2)
    end

    if cstr[bytesize - 1] < 128 || single_byte_optimizable?
      return byte_slice(0, bytesize - 1)
    end

    self[0, size - 1]
  end

  def strip
    excess_right = 0
    while cstr[bytesize - 1 - excess_right].chr.whitespace?
      excess_right += 1
    end

    if excess_right == bytesize
      return ""
    end

    excess_left = 0
    while cstr[excess_left].chr.whitespace?
      excess_left += 1
    end

    if excess_right == 0 && excess_left == 0
      self
    else
      String.new(unsafe_byte_slice excess_left, bytesize - excess_left - excess_right)
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
    reader = Char::Reader.new(to)
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

  # Returns a new string where the first character is yielded to the given
  # block and replaced by its return value.
  #
  # ```
  # "hello".sub {|x| (x.ord + 1).chr } #=> "iello"
  # "hello".sub { "hi" } #=> "hiello"
  # ```
  def sub(&block : Char -> _)
    return self if empty?

    String.build(bytesize) do |buffer|
      reader = Char::Reader.new(self)
      buffer << yield reader.current_char
      reader.next_char
      buffer.write unsafe_byte_slice(reader.pos)
    end
  end

  # Returns a string where the first occurrence of *char* is replaced by
  # *replacement*.
  #
  # ```
  # "hello".sub('l', "lo") #=> "helolo"
  # "hello world".sub('o', 'a') #=> "hella world"
  # ```
  def sub(char : Char, replacement)
    if includes?(char)
      String.build(bytesize) do |buffer|
        reader = Char::Reader.new(self)
        while reader.has_next?
          if reader.current_char == char
            buffer << replacement
            break
          else
            buffer << reader.current_char
          end
          reader.next_char
        end
        reader.next_char
        buffer.write unsafe_byte_slice(reader.pos)
      end
    else
      self
    end
  end

  # Returns a string where the first occurrence of *pattern* is replaced by
  # the block's return value.
  #
  # ```
  # "hello".sub(/./) {|s| s[0].ord.to_s + ' ' } #=> "104 ello"
  # ```
  def sub(pattern : Regex)
    match = pattern.match(self)
    return self unless match

    String.build(bytesize) do |buffer|
      buffer.write unsafe_byte_slice(0, match.byte_begin)
      str = match[0]
      $~ = match
      buffer << yield str, match
      buffer.write unsafe_byte_slice(match.byte_begin + str.bytesize)
    end
  end

  # Returns a string where the first occurrence of *pattern* is replaced by
  # *replacement*
  #
  # ```
  # "hello".sub(/[aeiou]/, '*') #=> "h*llo"
  # ```
  def sub(pattern : Regex, replacement)
    sub(pattern) { replacement }
  end

  # Returns a string where the first occurrences of the given *pattern* is replaced
  # with the matching entry from the *hash* of replacements. If the first match
  # is not included in the *hash*, nothing is replaced.
  #
  # ```
  # "hello".sub(/(he|l|o)/, {"he": "ha", "l": "la"}) #=> "hallo"
  # "hello".sub(/(he|l|o)/, {"l": "la"}) #=> "hello"
  # ```
  def sub(pattern : Regex, hash : Hash(String, _))
    sub(pattern) {|match|
      if hash.has_key?(match)
        hash[match]
      else
        return self
      end
    }
  end

  # Returns a string where the first occurrences of the given *string* is replaced
  # with the given *replacement*.
  #
  # ```
  # "hello yellow".sub("ll", "dd") #=> "heddo yellow"
  # ```
  def sub(string : String, replacement)
    sub(string) { replacement }
  end

  # Returns a string where the first occurrences of the given *string* is replaced
  # with the block's value.
  #
  # ```
  # "hello yellow".sub("ll") { "dd" } #=> "heddo yellow"
  # ```
  def sub(string : String, &block)
    index = self.index(string)
    return self unless index

    String.build(bytesize) do |buffer|
      buffer.write unsafe_byte_slice(0, index)
      buffer << yield string
      buffer.write unsafe_byte_slice(index + string.bytesize)
    end
  end

  # Returns a string where the first char in the string matching a key in the
  # given *hash* is replaced by the corresponding hash value.
  #
  # ```
  # "hello".sub({'a' => 'b', 'l' => 'd'}) #=> "hedlo"
  # ```
  def sub(hash : Hash(Char, _))
    return self if empty?

    String.build(bytesize) do |buffer|
      reader = Char::Reader.new(self)
      while reader.has_next?
        if hash.has_key?(reader.current_char)
          buffer << hash[reader.current_char]
          reader.next_char
          break
        else
          buffer << reader.current_char
          reader.next_char
        end
      end

      buffer << reader.current_char

      if reader.has_next?
        reader.next_char
        buffer.write unsafe_byte_slice(reader.pos)
      end
    end
  end

  # Returns a string where each character yielded to the given block
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
  def gsub(pattern : Regex)
    byte_offset = 0
    match = pattern.match_at_byte_index(self, byte_offset)
    return self unless match

    last_byte_offset = 0

    String.build(bytesize) do |buffer|
      while match
        index = match.byte_begin(0)

        buffer.write unsafe_byte_slice(last_byte_offset, index - last_byte_offset)
        str = match[0]
        $~ = match
        buffer << yield str, match

        if str.bytesize == 0
          byte_offset = index + 1
          last_byte_offset = index
        else
          byte_offset = index + str.bytesize
          last_byte_offset = byte_offset
        end

        match = pattern.match_at_byte_index(self, byte_offset)
      end

      if last_byte_offset < bytesize
        buffer.write unsafe_byte_slice(last_byte_offset)
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

  # Returns a string where all occurrences of the given *pattern* are replaced
  # with a *hash* of replacements. If the *hash* contains the matched pattern,
  # the corresponding value is used as a replacement. Otherwise the match is
  # not included in the returned string.
  #
  # ```
  # # "he" and "l" are matched and replaced,
  # # but "o" is not and so is not included
  # "hello".gsub(/(he|l|o)/, {"he": "ha", "l": "la"}) #=> "halala"
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

    last_byte_offset = 0

    String.build(bytesize) do |buffer|
      while index
        buffer.write unsafe_byte_slice(last_byte_offset, index - last_byte_offset)
        buffer << yield string

        if string.bytesize == 0
          byte_offset = index + 1
          last_byte_offset = index
        else
          byte_offset = index + string.bytesize
          last_byte_offset = byte_offset
        end

        index = self.byte_index(string, byte_offset)
      end

      if last_byte_offset < bytesize
        buffer.write unsafe_byte_slice(last_byte_offset)
      end
    end
  end

  # Returns a string where all chars in the given hash are replaced
  # by the corresponding *hash* values.
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
  def squeeze(*sets : String)
    squeeze {|char| char.in_set?(*sets) }
  end

  # Returns a new string, that has all characters removed,
  # that were the same as the previous one.
  #
  # ```
  # "a       bbb".squeeze #=> "a b"
  # ```
  def squeeze
    squeeze { true }
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
    nil
  end

  def +(other : self)
    size = bytesize + other.bytesize
    String.new(size) do |buffer|
      buffer.copy_from(cstr, bytesize)
      (buffer + bytesize).copy_from(other.cstr, other.bytesize)

      if size_known? && other.size_known?
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

      if size_known?
        {size, @length + 1}
      else
        {size, 0}
      end
    end
  end

  def *(times : Int)
    raise ArgumentError.new "negative argument" if times < 0

    if times == 0 || bytesize == 0
      return ""
    elsif bytesize == 1
      return String.new(times) do |buffer|
        Intrinsics.memset(buffer as Void*, cstr[0], times, 0, false)
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
    offset += size if offset < 0
    return nil if offset < 0

    each_char_with_index do |char, i|
      if i >= offset && char == c
        return i
      end
    end

    nil
  end

  def index(c : String, offset = 0)
    offset += size if offset < 0
    return nil if offset < 0

    end_pos = bytesize - c.bytesize

    reader = Char::Reader.new(self)
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

  def rindex(c : Char, offset = size - 1)
    offset += size if offset < 0
    return nil if offset < 0

    last_index = nil

    each_char_with_index do |char, i|
      if i <= offset && char == c
        last_index = i
      end
    end

    last_index
  end

  def rindex(c : String, offset = size - c.size)
    offset += size if offset < 0
    return nil if offset < 0

    end_size = size - c.size

    last_index = nil

    reader = Char::Reader.new(self)
    reader.each_with_index do |char, i|
      if i <= end_size && i <= offset && (cstr + reader.pos).memcmp(c.cstr, c.bytesize) == 0
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
  # It is valid to pass `size` to *index*, and in this case the answer
  # will be the bytesize of this string.
  #
  # ```
  # "hello".char_index_to_byte_index(1)     #=> 1
  # "hello".char_index_to_byte_index(5)     #=> 5
  # "こんにちは".char_index_to_byte_index(1) #=> 3
  # "こんにちは".char_index_to_byte_index(5) #=> 15
  # ```
  def char_index_to_byte_index(index)
    reader = Char::Reader.new(self)
    i = 0
    reader.each do |char|
      return reader.pos if i == index
      i += 1
    end
    return reader.pos if i == index
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
            piece_size = single_byte_optimizable ? piece_bytesize : 0
            ary.push String.new(cstr + index, piece_bytesize, piece_size)
            looking_for_space = false

            if limit && ary.size + 1 == limit
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
      piece_size = single_byte_optimizable ? piece_bytesize : 0
      ary.push String.new(cstr + index, piece_bytesize, piece_size)
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

    reader = Char::Reader.new(self)
    reader.each_with_index do |char, i|
      if char == separator
        piece_bytesize = reader.pos - byte_offset
        piece_size = single_byte_optimizable ? piece_bytesize : 0
        ary.push String.new(cstr + byte_offset, piece_bytesize, piece_size)
        byte_offset = reader.pos + reader.current_char_width
        break if limit && ary.size + 1 == limit
      end
    end

    if byte_offset != bytesize
      piece_bytesize = bytesize - byte_offset
      piece_size = single_byte_optimizable ? piece_bytesize : 0
      ary.push String.new(cstr + byte_offset, piece_bytesize, piece_size)
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
        break if limit && ary.size + 1 == limit
      end

      if limit && ary.size != size
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
        piece_size = single_byte_optimizable ? piece_bytesize : 0
        ary.push String.new(cstr + byte_offset, piece_bytesize, piece_size)
        byte_offset = i + separator_bytesize
        i += separator_bytesize - 1
        break if limit && ary.size + 1 == limit
      end
      i += 1
    end
    if byte_offset != bytesize
      piece_bytesize = bytesize - byte_offset
      piece_size = single_byte_optimizable ? piece_bytesize : 0
      ary.push String.new(cstr + byte_offset, piece_bytesize, piece_size)
    end
    ary
  end

  def split(separator : Regex, limit = nil)
    if limit && limit <= 1
      return [self]
    end

    ary = Array(String).new
    count = 0
    match_offset = 0
    slice_offset = 0
    last_slice_offset = 0

    while match = separator.match_at_byte_index(self, match_offset)
      index = match.byte_begin(0)
      slice_size = index - slice_offset
      match_bytesize = match[0].bytesize

      if slice_offset == 0 && slice_size == 0 && match_bytesize == 0
        # Skip
      elsif slice_offset == bytesize && slice_size == 0
        ary.push byte_slice(last_slice_offset)
      else
        ary.push byte_slice(slice_offset, slice_size)
      end
      count += 1

      1.upto(match.size) do |i|
        ary.push match[i]
      end

      last_slice_offset = slice_offset

      if match_bytesize == 0
        match_offset = index + 1
        slice_offset = index
      else
        match_offset = index + match_bytesize
        slice_offset = match_offset
      end
      break if limit && count + 1 == limit
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
    lines = [] of String
    each_line do |line|
      lines << line
    end
    lines
  end

  def each_line
    offset = 0

    while byte_index = byte_index('\n'.ord.to_u8, offset)
      yield String.new(unsafe_byte_slice(offset, byte_index + 1 - offset))
      offset = byte_index + 1
    end

    unless offset == bytesize
      yield String.new(unsafe_byte_slice(offset))
    end
  end

  def each_line
    LineIterator.new(self)
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
            else
              # case 1
              str << '_'
            end
            str << mem.downcase
            mem = nil
          end

          str << char.downcase
        end

        last_is_downcase = downcase
        last_is_upcase = upcase
        first = false
      end

      str << mem.downcase if mem
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
      reader = Char::Reader.new(self)
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
    return self if size >= len

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

    difference = len - size
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

  # Returns the successor of the string. The successor is calculated by incrementing characters starting from the rightmost
  # alphanumeric (or the rightmost character if there are no alphanumerics) in the string. Incrementing a digit always
  # results in another digit, and incrementing a letter results in another letter of the same case.
  #
  # If the increment generates a “carry”, the character to the left of it is incremented. This process repeats until
  # there is no carry, adding an additional character if necessary.
  #
  # ```
  # "abcd".succ        #=> "abce"
  # "THX1138".succ     #=> "THX1139"
  # "((koala))".succ   #=> "((koalb))"
  # "1999zzz".succ     #=> "2000aaa"
  # "ZZZ9999".succ     #=> "AAAA0000"
  # "***".succ         #=> "**+"
  # ```
  def succ
    return self if bytesize == 0

    chars = self.chars

    carry = nil
    last_alnum = 0
    index = size - 1

    while index >= 0
      s = chars[index]
      if s.alphanumeric?
        carry = 0
        if ('0' <= s && s < '9') ||
           ('a' <= s && s < 'z') ||
           ('A' <= s && s < 'Z')
          chars[index] = s.succ
          break
        elsif s == '9'
          chars[index] = '0'
          carry = '1'
        elsif s == 'z'
          chars[index] = carry = 'a'
        elsif s == 'Z'
          chars[index] = carry = 'A'
        end

        last_alnum = index
      end
      index -= 1
    end

    if carry.nil? # there were no alphanumeric chars
      chars[size - 1] = chars[size - 1].succ
    end

    if carry.is_a?(Char) && index < 0 # we still have a carry and already reached the beginning
      chars.insert(last_alnum, carry)
    end

    String.build(chars.size) do |str|
      chars.each do |char|
        str << char
      end
    end
  end

  def match(regex : Regex, pos = 0)
    match = regex.match self, pos
    $~ = match
    match
  end

  def match(regex : Regex, pos = 0)
    match = self.match(regex, pos)
    if match
      yield match
    end
  end

  def scan(pattern : Regex)
    byte_offset = 0

    while match = pattern.match_at_byte_index(self, byte_offset)
      index = match.byte_begin(0)
      $~ = match
      yield match
      match_bytesize = match[0].bytesize
      break if match_bytesize == 0
      byte_offset = index + match_bytesize
    end

    self
  end

  def scan(pattern : Regex)
    matches = [] of Regex::MatchData
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

  # Yields each character in the string to the block.
  #
  # ```
  # "ab☃".each_char do |char|
  #   char #=> 'a', 'b', '☃'
  # end
  # ```
  def each_char
    if single_byte_optimizable?
      each_byte do |byte|
        yield byte.chr
      end
    else
      Char::Reader.new(self).each do |char|
        yield char
      end
    end
    self
  end

  # Returns an iterator over each character in the string.
  #
  # ```
  # chars = "ab☃".each_char
  # chars.next #=> 'a'
  # chars.next #=> 'b'
  # chars.next #=> '☃'
  # ```
  def each_char
    CharIterator.new(Char::Reader.new(self))
  end

  # Yields each character and its index in the string to the block.
  #
  # ```
  # "ab☃".each_char_with_index do |char, index|
  #   char  #=> 'a', 'b', '☃'
  #   index #=>  0,   1,   2
  # end
  # ```
  def each_char_with_index
    i = 0
    each_char do |char|
      yield char, i
      i += 1
    end
    self
  end

  # Returns an array of all characters in the string.
  #
  # ```
  # "ab☃".chars #=> ['a', 'b', '☃']
  # ```
  def chars
    chars = Array(Char).new(@length > 0 ? @length : bytesize)
    each_char do |char|
      chars << char
    end
    chars
  end

  # Yields each codepoint to the block. See Char#ord
  #
  # ```
  # "ab☃".each_codepoint do |codepoint|
  #   codepoint #=> 97, 98, 9731
  # end
  # ```
  def each_codepoint
    each_char do |char|
      yield char.ord
    end
  end

  # Returns an iterator for each codepoint. See Char#ord
  #
  # ```
  # codepoints = "ab☃".each_codepoint
  # codepoints.next #=> 97
  # codepoints.next #=> 98
  # codepoints.next #=> 9731
  # ```
  def each_codepoint
    each_char.map &.ord
  end


  # Returns an array of the codepoints that make the string. See Char#ord
  #
  # ```
  # "ab☃".codepoints #=> [97, 98, 9731]
  # ```
  def codepoints
    codepoints = Array(Int32).new(@length > 0 ? @length : bytesize)
    each_codepoint do |codepoint|
      codepoints << codepoint
    end
    codepoints
  end

  # Yields each byte in the string to the block.
  #
  # ```
  # "ab☃".each_byte do |byte|
  #   byte #=> 97, 98, 226, 152, 131
  # end
  # ```
  def each_byte
    cstr.to_slice(bytesize).each do |byte|
      yield byte
    end
    self
  end

  # Returns an iterator over each byte in the string.
  #
  # ```
  # bytes = "ab☃".each_byte
  # bytes.next #=> 97
  # bytes.next #=> 98
  # bytes.next #=> 226
  # bytes.next #=> 156
  # bytes.next #=> 131
  # ```
  def each_byte
    to_slice.each
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

  def inspect(io)
    dump_or_inspect(io) do |char|
      inspect_char(char, io)
    end
  end

  def inspect_unquoted
    String.build do |io|
      inspect_unquoted(io)
    end
  end

  def inspect_unquoted(io)
    dump_or_inspect_unquoted(io) do |char|
      inspect_char(char, io)
    end
  end

  def dump
    String.build do |io|
      dump io
    end
  end

  def dump(io)
    dump_or_inspect(io) do |char|
      dump_char(char, io)
    end
  end

  def dump_unquoted
    String.build do |io|
      dump_unquoted(io)
    end
  end

  def dump_unquoted(io)
    dump_or_inspect_unquoted(io) do |char|
      dump_char(char, io)
    end
  end

  private def dump_or_inspect(io)
    io << "\""
    dump_or_inspect_unquoted(io) do |char|
      yield char
    end
    io << "\""
  end

  private def dump_or_inspect_unquoted(io)
    reader = Char::Reader.new(self)
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
  end

  private def inspect_char(char, io)
    if char.control?
      io << "\\u{"
      char.ord.to_s(16, io)
      io << "}"
    else
      io << char
    end
  end

  private def dump_char(char, io)
    if char.control? || char.ord >= 0x80
      io << "\\u{"
      char.ord.to_s(16, io)
      io << "}"
    else
      io << char
    end
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

  # Return a hash based on this string’s size and content.
  #
  # See also `Object#hash`.
  def hash
    h = 0
    each_byte do |c|
      h = 31 * h + c
    end
    h
  end

  # Returns the number of unicode codepoints in this string.
  #
  # ```
  # "hello".size         #=> 5
  # "你好".size          #=> 2
  # ```
  def size
    if @length > 0 || @bytesize == 0
      return @length
    end

    i = 0
    count = 0

    while i < bytesize
      c = cstr[i]

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

  def ascii_only?
    @bytesize == 0 || size == @bytesize
  end

  protected def single_byte_optimizable?
    @bytesize == @length
  end

  protected def size_known?
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

  # :nodoc:
  def self.check_capacity_in_bounds(capacity)
    if capacity < 0
      raise ArgumentError.new("negative capacity")
    end

    if capacity.to_u64 > (UInt32::MAX - HEADER_SIZE - 1)
      raise ArgumentError.new("capacity too big")
    end
  end

  # :nodoc:
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

  # :nodoc:
  class LineIterator
    include Iterator(String)

    def initialize(@string)
      @offset = 0
      @end = false
    end

    def next
      return stop if @end

      byte_index = @string.byte_index('\n'.ord.to_u8, @offset)
      if byte_index
        value = String.new(@string.unsafe_byte_slice(@offset, byte_index + 1 - @offset))
        @offset = byte_index + 1
      else
        if @offset == @string.bytesize
          value = stop
        else
          value = String.new(@string.unsafe_byte_slice(@offset))
        end
        @end = true
      end

      value
    end

    def rewind
      @offset = 0
      @end = false
      self
    end
  end
end

require "./string/formatter"
require "./string/builder"
