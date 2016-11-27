require "c/stdlib"
require "c/stdio"
require "c/string"

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
# ```
# "\101" # == "A"
# "\123" # == "S"
# "\12"  # == "\n"
# "\1"   # string with one character with code point 1
# ```
#
# You can use a backslash followed by an *u* and four hexadecimal characters to denote a unicode codepoint written:
#
# ```
# "\u0041" # == "A"
# ```
#
# Or you can use curly braces and specify up to six hexadecimal numbers (0 to 10FFFF):
#
# ```
# "\u{41}" # == "A"
# ```
#
# A string can span multiple lines:
#
# ```
# "hello
#       world" # same as "hello      \nworld"
# ```
#
# Note that in the above example trailing and leading spaces, as well as newlines,
# end up in the resulting string. To avoid this, you can split a string into multiple lines
# by joining multiple literals with a backslash:
#
# ```
# "hello " \
# "world, " \
# "no newlines" # same as "hello world, no newlines"
# ```
#
# Alternatively, a backslash followed by a newline can be inserted inside the string literal:
#
# ```
# "hello \
#      world, \
#      no newlines" # same as "hello world, no newlines"
# ```
#
# In this case, leading whitespace is not included in the resulting string.
#
# If you need to write a string that has many double quotes, parentheses, or similar
# characters, you can use alternative literals:
#
# ```
# # Supports double quotes and nested parentheses
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
# "sum = #{a + b}" # "sum = 3"
# ```
#
# This ends up invoking `Object#to_s(IO)` on each expression enclosed by `#{...}`.
#
# If you need to dynamically build a string, use `String#build` or `IO::Memory`.
class String
  # :nodoc:
  TYPE_ID = "".crystal_type_id

  # :nodoc:
  HEADER_SIZE = sizeof({Int32, Int32, Int32})

  include Comparable(self)

  # Creates a String from the given *slice*. Bytes will be copied from the slice.
  #
  # This method is always safe to call, and the resulting string will have
  # the contents and size of the slice.
  #
  # ```
  # slice = Slice.new(4) { |i| ('a'.ord + i).to_u8 }
  # String.new(slice) # => "abcd"
  # ```
  #
  # Note: if the slice doesn't denote a valid UTF-8 sequence, this method still succeeds.
  # However, when iterating it or indexing it, an `InvalidByteSequenceError` will be raised.
  def self.new(slice : Slice(UInt8))
    new(slice.pointer(slice.size), slice.size)
  end

  # Creates a new String from the given *bytes*, which are encoded in the given *encoding*.
  #
  # The *invalid* argument can be:
  # * `nil`: an exception is raised on invalid byte sequences
  # * `:skip`: invalid byte sequences are ignored
  #
  # ```
  # slice = Slice.new(2, 0_u8)
  # slice[0] = 186_u8
  # slice[1] = 195_u8
  # String.new(slice, "GB2312") # => "好"
  # ```
  def self.new(bytes : Slice(UInt8), encoding : String, invalid : Symbol? = nil) : String
    String.build do |str|
      String.encode(bytes, encoding, "UTF-8", str, invalid)
    end
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
  # String.new(ptr) # => "abcd"
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
  # str # => "ab"
  # ```
  #
  # Note: if the buffer doesn't end up denoting a valid UTF-8 sequence, this method still succeeds.
  # However, when iterating it or indexing it, an `InvalidByteSequenceError` will be raised.
  def self.new(capacity : Int)
    check_capacity_in_bounds(capacity)

    str = GC.malloc_atomic(capacity.to_u32 + HEADER_SIZE + 1).as(UInt8*)
    buffer = str.as(String).to_unsafe
    bytesize, size = yield buffer
    str_header = str.as({Int32, Int32, Int32}*)
    str_header.value = {TYPE_ID, bytesize.to_i, size.to_i}
    buffer[bytesize] = 0_u8
    str.as(String)
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
  # str # => "hello 1"
  # ```
  def self.build(capacity = 64) : self
    String::Builder.build(capacity) do |builder|
      yield builder
    end
  end

  # Returns the number of bytes in this string.
  #
  # ```
  # "hello".bytesize # => 5
  # "你好".bytesize    # => 6
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
  # "12345".to_i             # => 12345
  # "0a".to_i                # => 0
  # "hello".to_i             # => raises
  # "0a".to_i(16)            # => 10
  # "1100101".to_i(2)        # => 101
  # "1100101".to_i(8)        # => 294977
  # "1100101".to_i(10)       # => 1100101
  # "1100101".to_i(base: 16) # => 17826049
  #
  # "12_345".to_i                   # => raises
  # "12_345".to_i(underscore: true) # => 12345
  #
  # "  12345  ".to_i                    # => 12345
  # "  12345  ".to_i(whitepsace: false) # => raises
  #
  # "0x123abc".to_i               # => raises
  # "0x123abc".to_i(prefix: true) # => 1194684
  #
  # "99 red balloons".to_i                # => raises
  # "99 red balloons".to_i(strict: false) # => 99
  # ```
  def to_i(base : Int = 10, whitespace = true, underscore = false, prefix = false, strict = true)
    to_i32(base, whitespace, underscore, prefix, strict)
  end

  # Same as `#to_i`, but returns `nil` if there is not a valid number at the start
  # of this string, or if the resulting integer doesn't fit an Int32.
  #
  # ```
  # "12345".to_i?           # => 12345
  # "99 red balloons".to_i? # => 99
  # "0a".to_i?              # => 0
  # "hello".to_i?           # => nil
  # ```
  def to_i?(base : Int = 10, whitespace = true, underscore = false, prefix = false, strict = true)
    to_i32?(base, whitespace, underscore, prefix, strict)
  end

  # Same as `#to_i`, but returns the block's value if there is not a valid number at the start
  # of this string, or if the resulting integer doesn't fit an Int32.
  #
  # ```
  # "12345".to_i { 0 } # => 12345
  # "hello".to_i { 0 } # => 0
  # ```
  def to_i(base : Int = 10, whitespace = true, underscore = false, prefix = false, strict = true, &block)
    to_i32(base, whitespace, underscore, prefix, strict) { yield }
  end

  # Same as `#to_i` but returns an Int8.
  def to_i8(base : Int = 10, whitespace = true, underscore = false, prefix = false, strict = true) : Int8
    to_i8(base, whitespace, underscore, prefix, strict) { raise ArgumentError.new("invalid Int8: #{self}") }
  end

  # Same as `#to_i` but returns an Int8 or nil.
  def to_i8?(base : Int = 10, whitespace = true, underscore = false, prefix = false, strict = true) : Int8?
    to_i8(base, whitespace, underscore, prefix, strict) { nil }
  end

  # Same as `#to_i` but returns an Int8 or the block's value.
  def to_i8(base : Int = 10, whitespace = true, underscore = false, prefix = false, strict = true, &block)
    gen_to_ i8, 127, 128
  end

  # Same as `#to_i` but returns an UInt8.
  def to_u8(base : Int = 10, whitespace = true, underscore = false, prefix = false, strict = true) : UInt8
    to_u8(base, whitespace, underscore, prefix, strict) { raise ArgumentError.new("invalid UInt8: #{self}") }
  end

  # Same as `#to_i` but returns an UInt8 or nil.
  def to_u8?(base : Int = 10, whitespace = true, underscore = false, prefix = false, strict = true) : UInt8?
    to_u8(base, whitespace, underscore, prefix, strict) { nil }
  end

  # Same as `#to_i` but returns an UInt8 or the block's value.
  def to_u8(base : Int = 10, whitespace = true, underscore = false, prefix = false, strict = true, &block)
    gen_to_ u8, 255
  end

  # Same as `#to_i` but returns an Int16.
  def to_i16(base : Int = 10, whitespace = true, underscore = false, prefix = false, strict = true) : Int16
    to_i16(base, whitespace, underscore, prefix, strict) { raise ArgumentError.new("invalid Int16: #{self}") }
  end

  # Same as `#to_i` but returns an Int16 or nil.
  def to_i16?(base : Int = 10, whitespace = true, underscore = false, prefix = false, strict = true) : Int16?
    to_i16(base, whitespace, underscore, prefix, strict) { nil }
  end

  # Same as `#to_i` but returns an Int16 or the block's value.
  def to_i16(base : Int = 10, whitespace = true, underscore = false, prefix = false, strict = true, &block)
    gen_to_ i16, 32767, 32768
  end

  # Same as `#to_i` but returns an UInt16.
  def to_u16(base : Int = 10, whitespace = true, underscore = false, prefix = false, strict = true) : UInt16
    to_u16(base, whitespace, underscore, prefix, strict) { raise ArgumentError.new("invalid UInt16: #{self}") }
  end

  # Same as `#to_i` but returns an UInt16 or nil.
  def to_u16?(base : Int = 10, whitespace = true, underscore = false, prefix = false, strict = true) : UInt16?
    to_u16(base, whitespace, underscore, prefix, strict) { nil }
  end

  # Same as `#to_i` but returns an UInt16 or the block's value.
  def to_u16(base : Int = 10, whitespace = true, underscore = false, prefix = false, strict = true, &block)
    gen_to_ u16, 65535
  end

  # Same as `#to_i`.
  def to_i32(base : Int = 10, whitespace = true, underscore = false, prefix = false, strict = true) : Int32
    to_i32(base, whitespace, underscore, prefix, strict) { raise ArgumentError.new("invalid Int32: #{self}") }
  end

  # Same as `#to_i`.
  def to_i32?(base : Int = 10, whitespace = true, underscore = false, prefix = false, strict = true) : Int32?
    to_i32(base, whitespace, underscore, prefix, strict) { nil }
  end

  # Same as `#to_i`.
  def to_i32(base : Int = 10, whitespace = true, underscore = false, prefix = false, strict = true, &block)
    gen_to_ i32, 2147483647, 2147483648
  end

  # Same as `#to_i` but returns an UInt32.
  def to_u32(base : Int = 10, whitespace = true, underscore = false, prefix = false, strict = true) : UInt32
    to_u32(base, whitespace, underscore, prefix, strict) { raise ArgumentError.new("invalid UInt32: #{self}") }
  end

  # Same as `#to_i` but returns an UInt32 or nil.
  def to_u32?(base : Int = 10, whitespace = true, underscore = false, prefix = false, strict = true) : UInt32?
    to_u32(base, whitespace, underscore, prefix, strict) { nil }
  end

  # Same as `#to_i` but returns an UInt32 or the block's value.
  def to_u32(base : Int = 10, whitespace = true, underscore = false, prefix = false, strict = true, &block)
    gen_to_ u32, 4294967295
  end

  # Same as `#to_i` but returns an Int64.
  def to_i64(base : Int = 10, whitespace = true, underscore = false, prefix = false, strict = true) : Int64
    to_i64(base, whitespace, underscore, prefix, strict) { raise ArgumentError.new("invalid Int64: #{self}") }
  end

  # Same as `#to_i` but returns an Int64 or nil.
  def to_i64?(base : Int = 10, whitespace = true, underscore = false, prefix = false, strict = true) : Int64?
    to_i64(base, whitespace, underscore, prefix, strict) { nil }
  end

  # Same as `#to_i` but returns an Int64 or the block's value.
  def to_i64(base : Int = 10, whitespace = true, underscore = false, prefix = false, strict = true, &block)
    gen_to_ i64, 9223372036854775807, 9223372036854775808
  end

  # Same as `#to_i` but returns an UInt64.
  def to_u64(base : Int = 10, whitespace = true, underscore = false, prefix = false, strict = true) : UInt64
    to_u64(base, whitespace, underscore, prefix, strict) { raise ArgumentError.new("invalid UInt64: #{self}") }
  end

  # Same as `#to_i` but returns an UInt64 or nil.
  def to_u64?(base : Int = 10, whitespace = true, underscore = false, prefix = false, strict = true) : UInt64?
    to_u64(base, whitespace, underscore, prefix, strict) { nil }
  end

  # Same as `#to_i` but returns an UInt64 or the block's value.
  def to_u64(base : Int = 10, whitespace = true, underscore = false, prefix = false, strict = true, &block)
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
  CHAR_TO_DIGIT62 = begin
    table = CHAR_TO_DIGIT.clone
    26_i8.times do |i|
      table.to_unsafe[65 + i] = i + 36
    end
    table
  end

  # :nodoc:
  record ToU64Info,
    value : UInt64,
    negative : Bool,
    invalid : Bool

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
    raise ArgumentError.new("invalid base #{base}") unless 2 <= base <= 36 || base == 62

    ptr = to_unsafe

    # Skip leading whitespace
    if whitespace
      while ptr.value.unsafe_chr.ascii_whitespace?
        ptr += 1
      end
    end

    negative = false
    found_digit = false
    mul_overflow = ~0_u64 / base

    # Check + and -
    case ptr.value.unsafe_chr
    when '+'
      ptr += 1
    when '-'
      negative = true
      ptr += 1
    end

    # Check leading zero
    if ptr.value.unsafe_chr == '0'
      ptr += 1

      if prefix
        case ptr.value.unsafe_chr
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

    digits = (base == 62 ? CHAR_TO_DIGIT62 : CHAR_TO_DIGIT).to_unsafe
    while ptr.value != 0
      if ptr.value.unsafe_chr == '_' && underscore
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
          while ptr.value.unsafe_chr.ascii_whitespace?
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

  # Returns the result of interpreting characters in this string as a floating point number (`Float64`).
  # This method raises an exception if the string is not a valid float representation.
  #
  # Options:
  # * **whitespace**: if true, leading and trailing whitespaces are allowed
  # * **strict**: if true, extraneous characters past the end of the number are disallowed
  #
  # ```
  # "123.45e1".to_f                # => 1234.5
  # "45.67 degrees".to_f           # => 45.67
  # "thx1138".to_f                 # => ArgumentError
  # " 1.2".to_f(whitespace: false) # => ArgumentError
  # "1.2foo".to_f(strict: false)   # => 1.2
  # ```
  def to_f(whitespace = true, strict = true)
    to_f64(whitespace: whitespace, strict: strict)
  end

  # Returns the result of interpreting characters in this string as a floating point number (`Float64`).
  # This method returns `nil` if the string is not a valid float representation.
  #
  # Options:
  # * **whitespace**: if true, leading and trailing whitespaces are allowed
  # * **strict**: if true, extraneous characters past the end of the number are disallowed
  #
  # ```
  # "123.45e1".to_f?                # => 1234.5
  # "45.67 degrees".to_f?           # => 45.67
  # "thx1138".to_f?                 # => nil
  # " 1.2".to_f?(whitespace: false) # => nil
  # "1.2foo".to_f?(strict: false)   # => 1.2
  # ```
  def to_f?(whitespace = true, strict = true)
    to_f64?(whitespace: whitespace, strict: strict)
  end

  # Same as `#to_f` but returns a Float32.
  def to_f32(whitespace = true, strict = true)
    to_f32?(whitespace: whitespace, strict: strict) || raise ArgumentError.new("Invalid Float32: #{self}")
  end

  # Same as `#to_f?` but returns a Float32.
  def to_f32?(whitespace = true, strict = true)
    to_f_impl(whitespace: whitespace, strict: strict) do
      v = LibC.strtof self, out endptr
      {v, endptr}
    end
  end

  # Same as `#to_f`.
  def to_f64(whitespace = true, strict = true)
    to_f64?(whitespace: whitespace, strict: strict) || raise ArgumentError.new("Invalid Float64: #{self}")
  end

  # Same as `#to_f?`.
  def to_f64?(whitespace = true, strict = true)
    to_f_impl(whitespace: whitespace, strict: strict) do
      v = LibC.strtod self, out endptr
      {v, endptr}
    end
  end

  private def to_f_impl(whitespace = true, strict = true)
    return unless whitespace || '0' <= self[0] <= '9' || self[0] == '-' || self[0] == '+'

    v, endptr = yield
    string_end = to_unsafe + bytesize

    # blank string
    return if endptr == to_unsafe

    if strict
      if whitespace
        while endptr < string_end && endptr.value.chr.ascii_whitespace?
          endptr += 1
        end
      end
      # reached the end of the string
      v if endptr == string_end
    else
      ptr = to_unsafe
      if whitespace
        while ptr < string_end && ptr.value.chr.ascii_whitespace?
          ptr += 1
        end
      end
      # consumed some bytes
      v if endptr > ptr
    end
  end

  # Returns the `Char` at the given *index*, or raises `IndexError` if out of bounds.
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
  # "hello"[0..2]   # "hel"
  # "hello"[0...2]  # "he"
  # "hello"[1..-1]  # "ello"
  # "hello"[1...-1] # "ell"
  # ```
  def [](range : Range(Int, Int))
    from, size = range_to_index_and_size(range)
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
    if ascii_only?
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
      return self if count == bytesize

      String.new(count) do |buffer|
        buffer.copy_from(to_unsafe + start_pos, count)
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
    at(index) { raise IndexError.new }
  end

  def at(index : Int)
    if ascii_only?
      byte = byte_at?(index)
      return byte ? byte.unsafe_chr : yield
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
    single_byte_optimizable = ascii_only?

    if 0 <= start < bytesize
      raise ArgumentError.new "negative count" if count < 0

      count = bytesize - start if start + count > bytesize
      return "" if count == 0
      return self if count == bytesize

      String.new(count) do |buffer|
        buffer.copy_from(to_unsafe + start, count)
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
      to_unsafe[index]
    else
      yield
    end
  end

  def unsafe_byte_at(index)
    to_unsafe[index]
  end

  # Returns a new string with each uppercase letter replaced with its lowercase
  # counterpart.
  #
  # ```
  # "hEllO".downcase # => "hello"
  # ```
  def downcase(options = Unicode::CaseOptions::None)
    return self if empty?

    if ascii_only? && ((options == Unicode::CaseOptions::None) || options.ascii?)
      String.new(bytesize) do |buffer|
        bytesize.times do |i|
          buffer[i] = to_unsafe[i].unsafe_chr.downcase.ord.to_u8
        end
        {@bytesize, @length}
      end
    else
      String.build(bytesize) do |io|
        each_char do |char|
          char.downcase(options) do |res|
            io << res
          end
        end
      end
    end
  end

  # Returns a new string with each lowercase letter replaced with its uppercase
  # counterpart.
  #
  # ```
  # "hEllO".upcase # => "HELLO"
  # ```
  def upcase(options = Unicode::CaseOptions::None)
    return self if empty?

    if ascii_only? && ((options == Unicode::CaseOptions::None) || options.ascii?)
      String.new(bytesize) do |buffer|
        bytesize.times do |i|
          buffer[i] = to_unsafe[i].unsafe_chr.upcase.ord.to_u8
        end
        {@bytesize, @length}
      end
    else
      String.build(bytesize) do |io|
        each_char do |char|
          char.upcase(options) do |res|
            io << res
          end
        end
      end
    end
  end

  # Returns a new string with the first letter converted to uppercase and every
  # subsequent letter converted to lowercase.
  #
  # ```
  # "hEllO".capitalize # => "Hello"
  # ```
  def capitalize(options = Unicode::CaseOptions::None)
    return self if empty?

    if ascii_only? && ((options == Unicode::CaseOptions::None) || options.ascii?)
      String.new(bytesize) do |buffer|
        bytesize.times do |i|
          if i == 0
            buffer[i] = to_unsafe[i].unsafe_chr.upcase.ord.to_u8
          else
            buffer[i] = to_unsafe[i].unsafe_chr.downcase.ord.to_u8
          end
        end
        {@bytesize, @length}
      end
    else
      String.build(bytesize) do |io|
        each_char_with_index do |char, i|
          if i == 0
            char.upcase(options) { |c| io << c }
          else
            char.downcase(options) { |c| io << c }
          end
        end
      end
    end
  end

  # Returns a new String with the last carriage return removed (that is, it
  # will remove \n, \r, and \r\n).
  #
  # ```
  # "string\r\n".chomp # => "string"
  # "string\n\r".chomp # => "string\n"
  # "string\n".chomp   # => "string"
  # "string".chomp     # => "string"
  # "x".chomp.chmop    # => "x"
  # ```
  #
  # See also: `#chop`
  def chomp
    return self if empty?

    case to_unsafe[bytesize - 1]
    when '\n'
      if bytesize > 1 && to_unsafe[bytesize - 2] === '\r'
        unsafe_byte_slice_string(0, bytesize - 2)
      else
        unsafe_byte_slice_string(0, bytesize - 1)
      end
    when '\r'
      unsafe_byte_slice_string(0, bytesize - 1)
    else
      self
    end
  end

  # Returns a new String with *char* removed if the string ends with it.
  #
  # ```
  # "hello".chomp('o') # => "hell"
  # "hello".chomp('a') # => "hello"
  # ```
  def chomp(char : Char)
    if ends_with?(char)
      unsafe_byte_slice_string(0, bytesize - char.bytesize)
    else
      self
    end
  end

  # Returns a new String with *str* removed if the string ends with it.
  #
  # ```
  # "hello".chomp("llo") # => "he"
  # "hello".chomp("ol")  # => "hello"
  # ```
  def chomp(str : String)
    if ends_with?(str)
      unsafe_byte_slice_string(0, bytesize - str.bytesize)
    else
      self
    end
  end

  # Returns a new String with the last character removed.
  # If the string ends with `\r\n`, both characters are removed.
  # Applying chop to an empty string returns an empty string.
  #
  # ```
  # "string\r\n".chop # => "string"
  # "string\n\r".chop # => "string\n"
  # "string\n".chop   # => "string"
  # "string".chop     # => "strin"
  # "x".chop.chop     # => ""
  # ```
  #
  # See also: `#chomp`
  def chop
    return "" if bytesize <= 1

    if bytesize >= 2 && to_unsafe[bytesize - 1] === '\n' && to_unsafe[bytesize - 2] === '\r'
      return unsafe_byte_slice_string(0, bytesize - 2)
    end

    if to_unsafe[bytesize - 1] < 128 || ascii_only?
      return unsafe_byte_slice_string(0, bytesize - 1)
    end

    self[0, size - 1]
  end

  # Returns a slice of bytes containing this string encoded in the given encoding.
  #
  # The *invalid* argument can be:
  # * `nil`: an exception is raised on invalid byte sequences
  # * `:skip`: invalid byte sequences are ignored
  #
  # ```
  # "好".encode("GB2312") # => [186, 195]
  # "好".bytes            # => [229, 165, 189]
  # ```
  def encode(encoding : String, invalid : Symbol? = nil) : Slice(UInt8)
    io = IO::Memory.new
    String.encode(to_slice, "UTF-8", encoding, io, invalid)
    io.to_slice
  end

  # :nodoc:
  protected def self.encode(slice, from, to, io, invalid)
    IO::EncodingOptions.check_invalid(invalid)

    inbuf_ptr = slice.to_unsafe
    inbytesleft = LibC::SizeT.new(slice.size)
    outbuf = uninitialized UInt8[1024]

    Iconv.new(from, to, invalid) do |iconv|
      while inbytesleft > 0
        outbuf_ptr = outbuf.to_unsafe
        outbytesleft = LibC::SizeT.new(outbuf.size)
        err = iconv.convert(pointerof(inbuf_ptr), pointerof(inbytesleft), pointerof(outbuf_ptr), pointerof(outbytesleft))
        if err == -1
          iconv.handle_invalid(pointerof(inbuf_ptr), pointerof(inbytesleft))
        end
        io.write(outbuf.to_slice[0, outbuf.size - outbytesleft])
      end
    end
  end

  # Returns a new String that results of inserting *other* in *self* at *index*.
  # Negative indices count from the end of the string, and insert **after**
  # the given index.
  #
  # Raises `IndexError` if the index is out of bounds.
  #
  # ```
  # "abcd".insert(0, 'X')  # => "Xabcd"
  # "abcd".insert(3, 'X')  # => "abcXd"
  # "abcd".insert(4, 'X')  # => "abcdX"
  # "abcd".insert(-3, 'X') # => "abXcd"
  # "abcd".insert(-1, 'X') # => "abcdX"
  #
  # "abcd".insert(5, 'X')  # raises IndexError
  # "abcd".insert(-6, 'X') # raises IndexError
  # ```
  def insert(index : Int, other : Char)
    index = index.to_i
    index += size + 1 if index < 0

    byte_index = char_index_to_byte_index(index)
    raise IndexError.new unless byte_index

    bytes, count = String.char_bytes_and_bytesize(other)

    new_bytesize = bytesize + count
    new_size = ascii_only? ? new_bytesize : 0

    insert_impl(byte_index, bytes.to_unsafe, count, new_bytesize, new_size)
  end

  # Returns a new String that results of inserting *other* in *self* at *index*.
  # Negative indices count from the end of the string, and insert **after**
  # the given index.
  #
  # Raises `IndexError` if the index is out of bounds.
  #
  # ```
  # "abcd".insert(0, "FOO")  # => "FOOabcd"
  # "abcd".insert(3, "FOO")  # => "abcFOOd"
  # "abcd".insert(4, "FOO")  # => "abcdFOO"
  # "abcd".insert(-3, "FOO") # => "abFOOcd"
  # "abcd".insert(-1, "FOO") # => "abcdFOO"
  #
  # "abcd".insert(5, "FOO")  # raises IndexError
  # "abcd".insert(-6, "FOO") # raises IndexError
  # ```
  def insert(index : Int, other : String)
    index = index.to_i
    index += size + 1 if index < 0

    byte_index = char_index_to_byte_index(index)
    raise IndexError.new unless byte_index

    new_bytesize = bytesize + other.bytesize
    new_size = ascii_only? && other.ascii_only? ? new_bytesize : 0

    insert_impl(byte_index, other.to_unsafe, other.bytesize, new_bytesize, new_size)
  end

  private def insert_impl(byte_index, other, other_bytesize, new_bytesize, new_size)
    String.new(new_bytesize) do |buffer|
      buffer.copy_from(to_unsafe, byte_index)
      buffer += byte_index
      buffer.copy_from(other, other_bytesize)
      buffer += other_bytesize
      buffer.copy_from(to_unsafe + byte_index, bytesize - byte_index)
      {new_bytesize, new_size}
    end
  end

  # Returns a new string with leading and trailing whitespace removed.
  #
  # ```
  # "    hello    ".strip # => "hello"
  # "\tgoodbye\r\n".strip # => "goodbye"
  # ```
  def strip
    excess_right = calc_excess_right
    if excess_right == bytesize
      return ""
    end

    excess_left = calc_excess_left

    if excess_right == 0 && excess_left == 0
      self
    else
      unsafe_byte_slice_string(excess_left, bytesize - excess_left - excess_right)
    end
  end

  # Returns a new string with trailing whitespace removed.
  #
  # ```
  # "    hello    ".strip # => "    hello"
  # "\tgoodbye\r\n".strip # => "\tgoodbye"
  # ```
  def rstrip
    excess_right = calc_excess_right

    if excess_right == 0
      self
    else
      byte_slice 0, bytesize - excess_right
    end
  end

  # Returns a new string with leading whitespace removed.
  #
  # ```
  # "    hello    ".strip # => "hello    "
  # "\tgoodbye\r\n".strip # => "goodbye\r\n"
  # ```
  def lstrip
    excess_left = calc_excess_left

    if excess_left == 0
      self
    else
      byte_slice excess_left
    end
  end

  private def calc_excess_right
    i = bytesize - 1
    while i >= 0 && to_unsafe[i].unsafe_chr.ascii_whitespace?
      i -= 1
    end
    bytesize - 1 - i
  end

  private def calc_excess_left
    excess_left = 0
    # All strings end with '\0', and it's not a whitespace
    # so it's safe to access past 1 byte beyond the string data
    while to_unsafe[excess_left].unsafe_chr.ascii_whitespace?
      excess_left += 1
    end
    excess_left
  end

  # Returns a new string _tr_anslating characters using *from* and *to* as a
  # map. If *to* is shorter than *from*, the last character in *to* is used for
  # the rest. If *to* is empty, this acts like `String#delete`.
  #
  # ```
  # "aabbcc".tr("abc", "xyz") # => "xxyyzz"
  # "aabbcc".tr("abc", "x")   # => "xxxxxx"
  # "aabbcc".tr("a", "xyz")   # => "xxbbcc"
  # ```
  def tr(from : String, to : String)
    return delete(from) if to.empty?
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
            buffer << a.unsafe_chr
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
  # "hello".sub { |char| char + 1 } # => "iello"
  # "hello".sub { "hi" }            # => "hiello"
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
  # "hello".sub('l', "lo")      # => "helolo"
  # "hello world".sub('o', 'a') # => "hella world"
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
  # "hello".sub(/./) { |s| s[0].ord.to_s + ' ' } # => "104 ello"
  # ```
  def sub(pattern : Regex)
    sub_append(pattern) do |str, match, buffer|
      $~ = match
      buffer << yield str, match
    end
  end

  # Returns a string where the first occurrence of *pattern* is replaced by
  # *replacement*
  #
  # ```
  # "hello".sub(/[aeiou]/, "*") # => "h*llo"
  # ```
  #
  # Within *replacement*, the special match variable `$~` will not refer to the
  # current match.
  #
  # If *backreferences* is `true` (the default value), *replacement* can include backreferences:
  #
  # ```
  # "hello".sub(/[aeiou]/, "(\\0)") # => "h(e)llo"
  # ```
  #
  # When substitution is performed, any backreferences found in *replacement*
  # will be replaced with the contents of the corresponding capture group in
  # *pattern*. Backreferences to capture groups that were not present in
  # *pattern* or that did not match will be skipped. See `Regex` for information
  # about capture groups.
  #
  # Backreferences are expressed in the form `"\\d"`, where *d* is a group
  # number, or `"\\k&lt;name>"` where *name* is the name of a named capture group.
  # A sequence of literal characters resembling a backreference can be
  # expressed by placing `"\\"` before the sequence.
  #
  # ```
  # "foo".sub(/o/, "x\\0x")                  # => "fxoxo"
  # "foofoo".sub(/(?<bar>oo)/, "|\\k<bar>|") # => "f|oo|foo"
  # "foo".sub(/o/, "\\\\0")                  # => "f\\0o"
  # ```
  #
  # Raises `ArgumentError` if an incomplete named back-reference is present in
  # *replacement*.
  #
  # Raises `IndexError` if a named group referenced in *replacement* is not present
  # in *pattern*.
  def sub(pattern : Regex, replacement, backreferences = true)
    if backreferences && replacement.is_a?(String) && replacement.has_back_references?
      sub_append(pattern) { |_, match, buffer| scan_backreferences(replacement, match, buffer) }
    else
      sub(pattern) { replacement }
    end
  end

  # Returns a string where the first occurrences of the given *pattern* is replaced
  # with the matching entry from the *hash* of replacements. If the first match
  # is not included in the *hash*, nothing is replaced.
  #
  # ```
  # "hello".sub(/(he|l|o)/, {"he": "ha", "l": "la"}) # => "hallo"
  # "hello".sub(/(he|l|o)/, {"l": "la"})             # => "hello"
  # ```
  def sub(pattern : Regex, hash : Hash(String, _))
    sub(pattern) { |match|
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
  # "hello yellow".sub("ll", "dd") # => "heddo yellow"
  # ```
  def sub(string : String, replacement)
    sub(string) { replacement }
  end

  # Returns a string where the first occurrences of the given *string* is replaced
  # with the block's value.
  #
  # ```
  # "hello yellow".sub("ll") { "dd" } # => "heddo yellow"
  # ```
  def sub(string : String, &block)
    index = self.byte_index(string)
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
  # "hello".sub({'a' => 'b', 'l' => 'd'}) # => "hedlo"
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

  private def sub_append(pattern : Regex)
    match = pattern.match(self)
    return self unless match

    String.build(bytesize) do |buffer|
      buffer.write unsafe_byte_slice(0, match.byte_begin)
      str = match[0]
      $~ = match
      yield str, match, buffer
      buffer.write unsafe_byte_slice(match.byte_begin + str.bytesize)
    end
  end

  # Returns a new String with the character at the given index
  # replaced by *replacement*.
  #
  # ```
  # "hello".sub(1, 'a') # => "hallo"
  # ```
  def sub(index : Int, replacement : Char)
    sub_index(index.to_i, replacement) do |buffer|
      replacement.each_byte do |byte|
        buffer.value = byte
        buffer += 1
      end
      {buffer, @length}
    end
  end

  # Returns a new String with the character at the given index
  # replaced by *replacement*.
  #
  # ```
  # "hello".sub(1, "eee") # => "heeello"
  # ```
  def sub(index : Int, replacement : String)
    sub_index(index.to_i, replacement) do |buffer|
      buffer.copy_from(replacement.to_unsafe, replacement.bytesize)
      buffer += replacement.bytesize
      {buffer, self.size_known? && replacement.size_known? ? self.size + replacement.size - 1 : 0}
    end
  end

  private def sub_index(index, replacement)
    index += size + 1 if index < 0

    byte_index = char_index_to_byte_index(index)
    raise IndexError.new unless byte_index

    reader = Char::Reader.new(self)
    reader.pos = byte_index
    width = reader.current_char_width
    replacement_width = replacement.bytesize
    new_bytesize = bytesize - width + replacement_width

    String.new(new_bytesize) do |buffer|
      buffer.copy_from(to_unsafe, byte_index)
      buffer += byte_index
      buffer, length = yield buffer
      buffer.copy_from(to_unsafe + byte_index + width, bytesize - byte_index - width)
      {new_bytesize, length}
    end
  end

  # Returns a new String with characters at the given range
  # replaced by *replacement*.
  #
  # ```
  # "hello".sub(1..2, 'a') # => "halo"
  # ```
  def sub(range : Range(Int, Int), replacement : Char)
    sub_range(range, replacement) do |buffer, from_index, to_index|
      replacement.each_byte do |byte|
        buffer.value = byte
        buffer += 1
      end
      {buffer, ascii_only? ? bytesize - (to_index - from_index) + 1 : 0}
    end
  end

  # Returns a new String with characters at the given range
  # replaced by *replacement*.
  #
  # ```
  # "hello".sub(1..2, "eee") # => "heeelo"
  # ```
  def sub(range : Range(Int, Int), replacement : String)
    sub_range(range, replacement) do |buffer|
      buffer.copy_from(replacement.to_unsafe, replacement.bytesize)
      buffer += replacement.bytesize
      {buffer, 0}
    end
  end

  private def sub_range(range, replacement)
    from, size = range_to_index_and_size(range)

    from_index = char_index_to_byte_index(from)
    raise IndexError.new unless from_index

    if size == 0
      to_index = from_index
    else
      to_index = char_index_to_byte_index(from + size)
      raise IndexError.new unless to_index
    end

    new_bytesize = bytesize - (to_index - from_index) + replacement.bytesize

    String.new(new_bytesize) do |buffer|
      buffer.copy_from(to_unsafe, from_index)
      buffer += from_index
      buffer, length = yield buffer, from_index, to_index
      buffer.copy_from(to_unsafe + to_index, bytesize - to_index)
      {new_bytesize, length}
    end
  end

  # This returns true if this string has '\\' in it. It might not be a back reference,
  # but '\\' is probably used for back references, so this check is faster than parsing
  # the whole thing.
  def has_back_references?
    to_slice.index('\\'.ord.to_u8)
  end

  private def scan_backreferences(replacement, match_data, buffer)
    # We only append to the buffer in chunks, so if we have "foo\\1", we remember that
    # the chunk starts at index 0 (first_index) and when we find a "\\" we append
    # from 0 to 3 in a single write. When we find a "\\0" or "\\k<...>", we append
    # from the first_index, process the backreference, and then reset first_index
    # to the new index.
    first_index = 0
    index = 0

    while index = replacement.byte_index('\\'.ord.to_u8, index)
      index += 1
      chr = replacement.to_unsafe[index].unsafe_chr
      case chr
      when '\\'
        buffer.write(replacement.unsafe_byte_slice(first_index, index - first_index))
        index += 1
        first_index = index
      when '0'..'9'
        buffer.write(replacement.unsafe_byte_slice(first_index, index - 1 - first_index))
        buffer << match_data[chr - '0']?
        index += 1
        first_index = index
      when 'k'
        index += 1
        chr = replacement.to_unsafe[index].unsafe_chr
        next unless chr == '<'

        buffer.write(replacement.unsafe_byte_slice(first_index, index - 2 - first_index))

        index += 1
        start_index = index
        end_index = replacement.byte_index('>'.ord.to_u8, start_index)
        raise ArgumentError.new("missing ending '>' for '\\\\k<...'") unless end_index

        name = replacement.byte_slice(start_index, end_index - start_index)
        capture = match_data[name]?
        raise IndexError.new("undefined group name reference: #{name.inspect}") unless capture

        buffer << capture
        index = end_index + 1
        first_index = index
      end
    end

    if first_index != replacement.bytesize
      buffer.write(replacement.unsafe_byte_slice(first_index))
    end
  end

  # Returns a string where each character yielded to the given block
  # is replaced by the block's return value.
  #
  # ```
  # "hello".gsub { |char| char + 1 } # => "ifmmp"
  # "hello".gsub { "hi" }            # => "hihihihihi"
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
  # "hello".gsub('l', "lo")      # => "heloloo"
  # "hello world".gsub('o', 'a') # => "hella warld"
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
  # "hello".gsub(/./) { |s| s[0].ord.to_s + ' ' } # => #=> "104 101 108 108 111 "
  # ```
  def gsub(pattern : Regex)
    gsub_append(pattern) do |string, match, buffer|
      $~ = match
      buffer << yield string, match
    end
  end

  # Returns a string where all occurrences of the given *pattern* are replaced
  # with the given *replacement*.
  #
  # ```
  # "hello".gsub(/[aeiou]/, '*') # => "h*ll*"
  # ```
  #
  # Within *replacement*, the special match variable `$~` will not refer to the
  # current match.
  #
  # If *backreferences* is `true` (the default value), *replacement* can include backreferences:
  #
  # ```
  # "hello".gsub(/[aeiou]/, "(\\0)") # => "h(e)ll(o)"
  # ```
  #
  # When substitution is performed, any backreferences found in *replacement*
  # will be replaced with the contents of the corresponding capture group in
  # *pattern*. Backreferences to capture groups that were not present in
  # *pattern* or that did not match will be skipped. See `Regex` for information
  # about capture groups.
  #
  # Backreferences are expressed in the form `"\\d"`, where *d* is a group
  # number, or `"\\k&lt;name>"` where *name* is the name of a named capture group.
  # A sequence of literal characters resembling a backreference can be
  # expressed by placing `"\\"` before the sequence.
  #
  # ```
  # "foo".gsub(/o/, "x\\0x")                  # => "fxoxxox"
  # "foofoo".gsub(/(?<bar>oo)/, "|\\k<bar>|") # => "f|oo|f|oo|"
  # "foo".gsub(/o/, "\\\\0")                  # => "f\\0\\0"
  # ```
  #
  # Raises `ArgumentError` if an incomplete named back-reference is present in
  # *replacement*.
  #
  # Raises `IndexError` if a named group referenced in *replacement* is not present
  # in *pattern*.
  def gsub(pattern : Regex, replacement, backreferences = true)
    if backreferences && replacement.is_a?(String) && replacement.has_back_references?
      gsub_append(pattern) { |_, match, buffer| scan_backreferences(replacement, match, buffer) }
    else
      gsub(pattern) { replacement }
    end
  end

  # Returns a string where all occurrences of the given *pattern* are replaced
  # with a *hash* of replacements. If the *hash* contains the matched pattern,
  # the corresponding value is used as a replacement. Otherwise the match is
  # not included in the returned string.
  #
  # ```
  # # "he" and "l" are matched and replaced,
  # # but "o" is not and so is not included
  # "hello".gsub(/(he|l|o)/, {"he": "ha", "l": "la"}) # => "halala"
  # ```
  def gsub(pattern : Regex, hash : Hash(String, _) | NamedTuple)
    gsub(pattern) do |match|
      hash[match]?
    end
  end

  # Returns a string where all occurrences of the given *string* are replaced
  # with the given *replacement*.
  #
  # ```
  # "hello yellow".gsub("ll", "dd") # => "heddo yeddow"
  # ```
  def gsub(string : String, replacement)
    gsub(string) { replacement }
  end

  # Returns a string where all occurrences of the given *string* are replaced
  # with the block's value.
  #
  # ```
  # "hello yellow".gsub("ll") { "dd" } # => "heddo yeddow"
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
  # "hello".gsub({'e' => 'a', 'l' => 'd'}) # => "haddo"
  # ```
  def gsub(hash : Hash(Char, _))
    gsub do |char|
      hash[char]? || char
    end
  end

  # Returns a string where all chars in the given named tuple are replaced
  # by the corresponding *tuple* values.
  #
  # ```
  # "hello".gsub({e: 'a', l: 'd'}) # => "haddo"
  # ```
  def gsub(tuple : NamedTuple)
    gsub do |char|
      tuple[char.to_s]? || char
    end
  end

  private def gsub_append(pattern : Regex)
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
        yield str, match, buffer

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

  # Yields each char in this string to the block,
  # returns the number of times the block returned a truthy value.
  #
  # ```
  # "aabbcc".count { |c| ['a', 'b'].includes?(c) } # => 4
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
  # "aabbcc".count('a') # => 2
  # ```
  def count(other : Char)
    count { |char| char == other }
  end

  # Sets should be a list of strings following the rules
  # described at Char#in_set?. Returns the number of characters
  # in this string that match the given set.
  def count(*sets)
    count { |char| char.in_set?(*sets) }
  end

  # Yields each char in this string to the block.
  # Returns a new string with all characters for which the
  # block returned a truthy value removed.
  #
  # ```
  # "aabbcc".delete { |c| ['a', 'b'].includes?(c) } # => "cc"
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
  # "aabbcc".delete('b') # => "aacc"
  # ```
  def delete(char : Char)
    delete { |my_char| my_char == char }
  end

  # Sets should be a list of strings following the rules
  # described at Char#in_set?. Returns a new string with
  # all characters that match the given set removed.
  #
  # ```
  # "aabbccdd".delete("a-c") # => "dd"
  # ```
  def delete(*sets)
    delete { |char| char.in_set?(*sets) }
  end

  # Yields each char in this string to the block.
  # Returns a new string, that has all characters removed,
  # that were the same as the previous one and for which the given
  # block returned a truthy value.
  #
  # ```
  # "aaabbbccc".squeeze { |c| ['a', 'b'].includes?(c) } # => "abccc"
  # "aaabbbccc".squeeze { |c| ['a', 'c'].includes?(c) } # => "abbbc"
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
  # "a    bbb".squeeze(' ') # => "a bbb"
  # ```
  def squeeze(char : Char)
    squeeze { |my_char| char == my_char }
  end

  # Sets should be a list of strings following the rules
  # described at Char#in_set?. Returns a new string with all
  # runs of the same character replaced by one instance, if
  # they match the given set.
  #
  # If no set is given, all characters are matched.
  #
  # ```
  # "aaabbbcccddd".squeeze("b-d") # => "aaabcd"
  # "a       bbb".squeeze         # => "a b"
  # ```
  def squeeze(*sets : String)
    squeeze { |char| char.in_set?(*sets) }
  end

  # Returns a new string, that has all characters removed,
  # that were the same as the previous one.
  #
  # ```
  # "a       bbb".squeeze # => "a b"
  # ```
  def squeeze
    squeeze { true }
  end

  # Returns true if this is the empty string, `""`.
  def empty?
    bytesize == 0
  end

  # Returns true if this string consists exclusively of unicode whitespace.
  #
  # ```
  # "".blank?        # => true
  # "   ".blank?     # => true
  # "   a   ".blank? # => false
  # ```
  def blank?
    each_char do |char|
      return false unless char.whitespace?
    end
    true
  end

  def ==(other : self)
    return true if same?(other)
    return false unless bytesize == other.bytesize
    to_unsafe.memcmp(other.to_unsafe, bytesize) == 0
  end

  # Compares this string with *other*, returning -1, 0 or +1 depending on whether
  # this string is less, equal or greater than *other*.
  #
  # Comparison is done byte-per-byte: if a byte is less then the other corresponding
  # byte, -1 is returned and so on.
  #
  # If the strings are of different lengths, and the strings are equal when compared
  # up to the shortest length, then the longer string is considered greater than
  # the shorter one.
  #
  # ```
  # "abcdef" <=> "abcde"   # => 1
  # "abcdef" <=> "abcdef"  # => 0
  # "abcdef" <=> "abcdefg" # => -1
  # "abcdef" <=> "ABCDEF"  # => 1
  # ```
  def <=>(other : self)
    return 0 if same?(other)
    min_bytesize = Math.min(bytesize, other.bytesize)

    cmp = to_unsafe.memcmp(other.to_unsafe, bytesize)
    cmp == 0 ? (bytesize <=> other.bytesize) : cmp.sign
  end

  # Compares this string with *other*, returning -1, 0 or +1 depending on whether
  # this string is less, equal or greater than *other*, optionally in a *case_insensitive*
  # manner.
  #
  # If *case_insitive* if `false`, this method delegates to `<=>`. Otherwise,
  # the strings are compared char-by-char, and ASCII characters are compared in a
  # case-insensitive way.
  #
  # ```
  # "abcdef".compare("abcde")   # => 1
  # "abcdef".compare("abcdef")  # => 0
  # "abcdef".compare("abcdefg") # => -1
  # "abcdef".compare("ABCDEF")  # => 1
  #
  # "abcdef".compare("ABCDEF", case_insensitive: true) # => 0
  # "abcdef".compare("ABCDEG", case_insensitive: true) # => -1
  # ```
  def compare(other : String, case_insensitive = false)
    return self <=> other unless case_insensitive

    reader1 = Char::Reader.new(self)
    reader2 = Char::Reader.new(other)
    ch1 = reader1.current_char
    ch2 = reader2.current_char

    while reader1.has_next? && reader2.has_next?
      cmp = ch1.downcase <=> ch2.downcase
      return cmp.sign if cmp != 0

      ch1 = reader1.next_char
      ch2 = reader2.next_char
    end

    if reader1.has_next?
      1
    elsif reader2.has_next?
      -1
    else
      0
    end
  end

  # Tests whether *str* matches *regex*.
  # If successful, it returns the position of the first match.
  # If unsuccessful, it returns `nil`.
  #
  # If the argument isn't a `Regex`, it returns `nil`.
  #
  # ```
  # "Haystack" =~ /ay/ # => 1
  # "Haystack" =~ /z/  # => nil
  #
  # "Haystack" =~ 45 # => nil
  # ```
  def =~(regex : Regex)
    match = regex.match(self)
    $~ = match
    match.try &.begin(0)
  end

  # ditto
  def =~(other)
    nil
  end

  # Concatenates *str* and *other*.
  #
  # ```
  # "abc" + "def" # => "abcdef"
  # "abc" + 'd'   # => "abcd"
  # ```
  def +(other : self)
    return self if other.empty?
    return other if self.empty?

    size = bytesize + other.bytesize
    String.new(size) do |buffer|
      buffer.copy_from(to_unsafe, bytesize)
      (buffer + bytesize).copy_from(other.to_unsafe, other.bytesize)

      if size_known? && other.size_known?
        {size, @length + other.@length}
      else
        {size, 0}
      end
    end
  end

  # ditto
  def +(char : Char)
    bytes, count = String.char_bytes_and_bytesize(char)
    size = bytesize + count
    String.new(size) do |buffer|
      buffer.copy_from(to_unsafe, bytesize)
      (buffer + bytesize).copy_from(bytes.to_unsafe, count)

      if size_known?
        {size, @length + 1}
      else
        {size, 0}
      end
    end
  end

  # Makes a new string by adding *str* to itself *times* times.
  #
  # ```
  # "Developers! " * 4
  # # => "Developers! Developers! Developers! Developers!"
  # ```
  def *(times : Int)
    raise ArgumentError.new "negative argument" if times < 0

    if times == 0 || bytesize == 0
      return ""
    elsif bytesize == 1
      return String.new(times) do |buffer|
        Intrinsics.memset(buffer.as(Void*), to_unsafe[0], times, 0, false)
        {times, times}
      end
    end

    total_bytesize = bytesize * times
    String.new(total_bytesize) do |buffer|
      buffer.copy_from(to_unsafe, bytesize)
      n = bytesize

      while n <= total_bytesize / 2
        (buffer + n).copy_from(buffer, n)
        n *= 2
      end

      (buffer + n).copy_from(buffer, total_bytesize - n)
      {total_bytesize, @length * times}
    end
  end

  # Returns the index of *search* in the string, or `nil` if the string is not present.
  # If `offset` is present, it defines the position to start the search.
  #
  # ```
  # "Hello, World".index('o')    # => 4
  # "Hello, World".index('Z')    # => nil
  # "Hello, World".index("o", 5) # => 8
  # "Hello, World".index("H", 2) # => nil
  # "Hello, World".index(/[ ]+/) # => 5
  # "Hello, World".index(/d+/)   # => nil
  # ```
  def index(search : Char, offset = 0)
    # If it's ASCII we can delegate to slice
    if search.ascii? && ascii_only?
      return to_slice.index(search.ord.to_u8, offset)
    end

    offset += size if offset < 0
    return nil if offset < 0

    each_char_with_index do |char, i|
      if i >= offset && char == search
        return i
      end
    end

    nil
  end

  # ditto
  def index(search : String, offset = 0)
    offset += size if offset < 0
    return nil if offset < 0

    end_pos = bytesize - search.bytesize

    reader = Char::Reader.new(self)
    reader.each_with_index do |char, i|
      if reader.pos <= end_pos
        if i >= offset && (to_unsafe + reader.pos).memcmp(search.to_unsafe, search.bytesize) == 0
          return i
        end
      else
        break
      end
    end

    nil
  end

  # ditto
  def index(search : Regex, offset = 0)
    offset += size if offset < 0
    return nil unless 0 <= offset <= size

    self.match(search, offset).try &.begin
  end

  # Returns the index of the _last_ appearance of *c* in the string,
  # If `offset` is present, it defines the position to _end_ the search
  # (characters beyond this point are ignored).
  #
  # ```
  # "Hello, World".rindex('o')    # => 8
  # "Hello, World".rindex('Z')    # => nil
  # "Hello, World".rindex("o", 5) # => 4
  # "Hello, World".rindex("H", 2) # => nil
  # ```
  def rindex(search : Char, offset = size - 1)
    # If it's ASCII we can delegate to slice
    if search.ascii? && ascii_only?
      return to_slice.rindex(search.ord.to_u8, offset)
    end

    offset += size if offset < 0
    return nil if offset < 0

    last_index = nil

    each_char_with_index do |char, i|
      if i <= offset && char == search
        last_index = i
      end
    end

    last_index
  end

  # ditto
  def rindex(search : String, offset = size - search.size)
    offset += size if offset < 0
    return nil if offset < 0

    end_size = size - search.size

    last_index = nil

    reader = Char::Reader.new(self)
    reader.each_with_index do |char, i|
      if i <= end_size && i <= offset && (to_unsafe + reader.pos).memcmp(search.to_unsafe, search.bytesize) == 0
        last_index = i
      end
    end

    last_index
  end

  # ditto
  def rindex(search : Regex, offset = 0)
    offset += size if offset < 0
    return nil unless 0 <= offset <= size

    match_result = nil
    self[0, self.size - offset].scan(search) do |match_data|
      match_result = match_data
    end

    match_result.try &.begin(0)
  end

  # Searches sep or pattern (regexp) in the string,
  # and returns the part before it, the match, and the part after it.
  # If it is not found, returns str followed by two empty strings.
  #
  # ```
  # "hello".partition("l") # => {"he", "l", "lo"}
  # "hello".partition("x") # => {"hello", "", ""}
  # ```
  def partition(search : (Char | String)) : Tuple(String, String, String)
    pre = mid = post = ""
    search_size = search.is_a?(Char) ? 1 : search.size
    case pos = self.index(search)
    when .nil?
      pre = self
    when 0
      mid = search.to_s
      post = self[(pos + search_size)..-1]
    else
      pre = self[0..(pos - 1)]
      mid = search.to_s
      post = self[(pos + search_size)..-1]
    end
    {pre, mid, post}
  end

  # ditto
  def partition(search : Regex) : Tuple(String, String, String)
    pre = mid = post = ""
    case m = self.match(search)
    when .nil?
      pre = self
    else
      pre = m.pre_match
      mid = m[0]
      post = m.post_match
    end
    {pre, mid, post}
  end

  # Searches sep or pattern (regexp) in the string from the end of the string,
  # and returns the part before it, the match, and the part after it.
  # If it is not found, returns two empty strings and str.
  #
  # ```
  # "hello".rpartition("l")  # => {"hel", "l", "o"}
  # "hello".rpartition("x")  # => {"", "", "hello"}
  # "hello".rpartition(/.l/) # => {"he", "ll", "o"}
  # ```
  def rpartition(search : (Char | String)) : Tuple(String, String, String)
    pos = self.rindex(search)
    search_size = search.is_a?(Char) ? 1 : search.size

    pre = mid = post = ""

    case pos
    when .nil?
      post = self
    when 0
      mid = search.to_s
      post = self[(pos + search_size)..-1]
    else
      pre = self[0..(pos - 1)]
      mid = search.to_s
      post = self[(pos + search_size)..-1]
    end
    {pre, mid, post}
  end

  # ditto
  def rpartition(search : Regex) : Tuple(String, String, String)
    match_result = nil
    pos = self.size - 1

    while pos >= 0
      self[pos..-1].scan(search) do |m|
        match_result = m
      end
      break unless match_result.nil?
      pos -= 1
    end

    pre = mid = post = ""

    case
    when match_result.nil?
      post = self
    when pos == 0
      mid = match_result[0]
      post = self[match_result[0].size..-1]
    else
      pre = self[0..pos - 1]
      mid = match_result.not_nil![0]
      post = self[pos + match_result.not_nil![0].size..-1]
    end
    {pre, mid, post}
  end

  def byte_index(byte : Int, offset = 0)
    offset.upto(bytesize - 1) do |i|
      if to_unsafe[i] == byte
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
      if (to_unsafe + pos).memcmp(string.to_unsafe, string.bytesize) == 0
        return pos
      end
    end

    nil
  end

  # Returns the byte index of a char index, or nil if out of bounds.
  #
  # It is valid to pass `size` to *index*, and in this case the answer
  # will be the bytesize of this string.
  #
  # ```
  # "hello".char_index_to_byte_index(1) # => 1
  # "hello".char_index_to_byte_index(5) # => 5
  # "こんにちは".char_index_to_byte_index(1) # => 3
  # "こんにちは".char_index_to_byte_index(5) # => 15
  # ```
  def char_index_to_byte_index(index)
    if ascii_only?
      return 0 <= index <= bytesize ? index : nil
    end

    size = each_byte_index_and_char_index do |byte_index, char_index|
      return byte_index if index == char_index
    end
    return @bytesize if index == size
    nil
  end

  # Returns the char index of a byte index, or nil if out of bounds.
  #
  # It is valid to pass `bytesize` to *index*, and in this case the answer
  # will be the size of this string.
  def byte_index_to_char_index(index)
    if ascii_only?
      return 0 <= index <= bytesize ? index : nil
    end

    size = each_byte_index_and_char_index do |byte_index, char_index|
      return char_index if index == byte_index
    end
    return size if index == @bytesize
    nil
  end

  # Returns true if the string contains *search*.
  #
  # ```
  # "Team".includes?('i')            # => false
  # "Dysfunctional".includes?("fun") # => true
  # ```
  def includes?(search : Char | String)
    !!index(search)
  end

  # Makes an array by splitting the string on any ASCII whitespace characters (and removing that whitespace).
  #
  # If *limit* is present, up to *limit* new strings will be created,
  # with the entire remainder added to the last string.
  #
  # ```
  # old_pond = "
  #   Old pond
  #   a frog leaps in
  #   water's sound
  # "
  # old_pond.split    # => ["Old", "pond", "a", "frog", "leaps", "in", "water's", "sound"]
  # old_pond.split(3) # => ["Old", "pond", "a frog leaps in\n  water's sound\n"]
  # ```
  def split(limit : Int32? = nil)
    if limit && limit <= 1
      return [self]
    end

    ary = Array(String).new
    single_byte_optimizable = ascii_only?
    index = 0
    i = 0
    looking_for_space = false
    limit_reached = false
    while i < bytesize
      if looking_for_space
        while i < bytesize
          c = to_unsafe[i]
          i += 1
          if c.unsafe_chr.ascii_whitespace?
            piece_bytesize = i - 1 - index
            piece_size = single_byte_optimizable ? piece_bytesize : 0
            ary.push String.new(to_unsafe + index, piece_bytesize, piece_size)
            looking_for_space = false

            if limit && ary.size + 1 == limit
              limit_reached = true
            end

            break
          end
        end
      else
        while i < bytesize
          c = to_unsafe[i]
          i += 1
          unless c.unsafe_chr.ascii_whitespace?
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
      ary.push String.new(to_unsafe + index, piece_bytesize, piece_size)
    end
    ary
  end

  # Makes an array by splitting the string on the given character *separator* (and removing that character).
  #
  # If *limit* is present, up to *limit* new strings will be created,
  # with the entire remainder added to the last string.
  #
  # ```
  # "foo,bar,baz".split(',')    # => ["foo", "bar", "baz"]
  # "foo,bar,baz".split(',', 2) # => ["foo", "bar,baz"]
  # ```
  def split(separator : Char, limit = nil)
    if empty? || (limit && limit <= 1)
      return [self]
    end

    ary = Array(String).new

    byte_offset = 0
    single_byte_optimizable = ascii_only?

    reader = Char::Reader.new(self)
    reader.each_with_index do |char, i|
      if char == separator
        piece_bytesize = reader.pos - byte_offset
        piece_size = single_byte_optimizable ? piece_bytesize : 0
        ary.push String.new(to_unsafe + byte_offset, piece_bytesize, piece_size)
        byte_offset = reader.pos + reader.current_char_width
        break if limit && ary.size + 1 == limit
      end
    end

    piece_bytesize = bytesize - byte_offset
    piece_size = single_byte_optimizable ? piece_bytesize : 0
    ary.push String.new(to_unsafe + byte_offset, piece_bytesize, piece_size)

    ary
  end

  # Makes an array by splitting the string on *separator* (and removing instances of *separator*).
  #
  # If *limit* is present, the array will be limited to *limit* items and
  # the final item will contain the remainder of the string.
  #
  # If *separator* is an empty string (`""`), the string will be separated into one-character strings.
  #
  # ```
  # long_river_name = "Mississippi"
  # long_river_name.split("ss") # => ["Mi", "i", "ippi"]
  # long_river_name.split("i")  # => ["M", "ss", "ss", "pp"]
  # long_river_name.split("")   # => ["M", "i", "s", "s", "i", "s", "s", "i", "p", "p", "i"]
  # ```
  def split(separator : String, limit = nil)
    if empty? || (limit && limit <= 1)
      return [self]
    end

    if separator.empty?
      return split_by_empty_separator(limit)
    end

    ary = Array(String).new
    byte_offset = 0
    separator_bytesize = separator.bytesize

    single_byte_optimizable = ascii_only?

    i = 0
    stop = bytesize - separator.bytesize + 1
    while i < stop
      if (to_unsafe + i).memcmp(separator.to_unsafe, separator_bytesize) == 0
        piece_bytesize = i - byte_offset
        piece_size = single_byte_optimizable ? piece_bytesize : 0
        ary.push String.new(to_unsafe + byte_offset, piece_bytesize, piece_size)
        byte_offset = i + separator_bytesize
        i += separator_bytesize - 1
        break if limit && ary.size + 1 == limit
      end
      i += 1
    end

    piece_bytesize = bytesize - byte_offset
    piece_size = single_byte_optimizable ? piece_bytesize : 0
    ary.push String.new(to_unsafe + byte_offset, piece_bytesize, piece_size)

    ary
  end

  # Makes an array by splitting the string on *separator* (and removing instances of *separator*).
  #
  # If *limit* is present, the array will be limited to *limit* items and
  # the final item will contain the remainder of the string.
  #
  # If *separator* is an empty regex (`//`), the string will be separated into one-character strings.
  #
  # ```
  # long_river_name = "Mississippi"
  # long_river_name.split(/s+/) # => ["Mi", "i", "ippi"]
  # long_river_name.split(//)   # => ["M", "i", "s", "s", "i", "s", "s", "i", "p", "p", "i"]
  # ```
  def split(separator : Regex, limit = nil)
    if empty? || (limit && limit <= 1)
      return [self]
    end

    if separator.source.empty?
      return split_by_empty_separator(limit)
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
        if group = match[i]?
          ary.push group
        end
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

    ary.push byte_slice(slice_offset)

    ary
  end

  private def split_by_empty_separator(limit)
    ary = Array(String).new

    each_char do |c|
      ary.push c.to_s
      break if limit && ary.size + 1 == limit
    end

    if limit && ary.size != size
      ary.push(self[ary.size..-1])
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

  # Splits the string after each newline and yields each line to a block.
  #
  # ```
  # haiku = "the first cold shower
  # even the monkey seems to want
  # a little coat of straw"
  # haiku.each_line do |stanza|
  #   puts stanza.upcase
  # end
  # # => THE FIRST COLD SHOWER
  # # => EVEN THE MONKEY SEEMS TO want
  # # => A LITTLE COAT OF STRAW
  # ```
  def each_line
    offset = 0

    while byte_index = byte_index('\n'.ord.to_u8, offset)
      yield unsafe_byte_slice_string(offset, byte_index + 1 - offset)
      offset = byte_index + 1
    end

    unless offset == bytesize
      yield unsafe_byte_slice_string(offset)
    end
  end

  # Returns an `Iterator` which yields each line of this string (see `String#each_line`).
  def each_line
    LineIterator.new(self)
  end

  # Converts camelcase boundaries to underscores.
  #
  # ```
  # "DoesWhatItSaysOnTheTin".underscore # => "does_what_it_says_on_the_tin"
  # "PartyInTheUSA".underscore          # => "party_in_the_usa"
  # "HTTP_CLIENT".underscore            # => "http_client"
  # ```
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

  # Converts underscores to camelcase boundaries.
  #
  # ```
  # "eiffel_tower".camelcase # => "EiffelTower"
  # ```
  def camelcase
    return self if empty?

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

  # Reverses the order of characters in the string.
  #
  # ```
  # "Argentina".reverse # => "anitnegrA"
  # "racecar".reverse   # => "racecar"
  # ```
  def reverse
    return self if bytesize <= 1

    if ascii_only?
      String.new(bytesize) do |buffer|
        bytesize.times do |i|
          buffer[i] = self.to_unsafe[bytesize - i - 1]
        end
        {@bytesize, @length}
      end
    else
      # Iterate grpahemes to reverse the string,
      # so combining characters are placed correctly
      String.new(bytesize) do |buffer|
        buffer += bytesize
        scan(/\X/) do |match|
          grapheme = match[0]
          buffer -= grapheme.bytesize
          buffer.copy_from(grapheme.to_unsafe, grapheme.bytesize)
        end
        {@bytesize, @length}
      end
    end
  end

  # Adds instances of `char` to right of the string until it is at least size of `len`.
  #
  # ```
  # "Purple".ljust(8)      # => "Purple  "
  # "Purple".ljust(8, '-') # => "Purple--"
  # "Aubergine".ljust(8)   # => "Aubergine"
  # ```
  def ljust(len, char : Char = ' ')
    just len, char, true
  end

  # Adds instances of `char` to left of the string until it is at least size of `len`.
  #
  # ```
  # "Purple".ljust(8)      # => "  Purple"
  # "Purple".ljust(8, '-') # => "--Purple"
  # "Aubergine".ljust(8)   # => "Aubergine"
  # ```
  def rjust(len, char : Char = ' ')
    just len, char, false
  end

  private def just(len, char, left)
    return self if size >= len

    bytes, count = String.char_bytes_and_bytesize(char)

    difference = len - size
    new_bytesize = bytesize + difference * count

    String.new(new_bytesize) do |buffer|
      if left
        buffer.copy_from(to_unsafe, bytesize)
        buffer += bytesize
      end

      if count == 1
        Intrinsics.memset(buffer.as(Void*), char.ord.to_u8, difference.to_u32, 0_u32, false)
        buffer += difference
      else
        difference.times do
          buffer.copy_from(bytes.to_unsafe, count)
          buffer += count
        end
      end

      unless left
        buffer.copy_from(to_unsafe, bytesize)
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
  # "abcd".succ      # => "abce"
  # "THX1138".succ   # => "THX1139"
  # "((koala))".succ # => "((koalb))"
  # "1999zzz".succ   # => "2000aaa"
  # "ZZZ9999".succ   # => "AAAA0000"
  # "***".succ       # => "**+"
  # ```
  def succ
    return self if empty?

    chars = self.chars

    carry = nil
    last_alnum = 0
    index = size - 1

    while index >= 0
      s = chars[index]
      if s.ascii_alphanumeric?
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

  # Finds match of *regex*, starting at *pos*.
  def match(regex : Regex, pos = 0) : Regex::MatchData?
    match = regex.match self, pos
    $~ = match
    match
  end

  # Searches the string for instances of *pattern*, yielding a `Regex::MatchData` for each match.
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

  # Searches the string for instances of *pattern*,
  # returning an array of `Regex::MatchData` for each match.
  def scan(pattern : Regex)
    matches = [] of Regex::MatchData
    scan(pattern) do |match|
      matches << match
    end
    matches
  end

  # Searches the string for instances of *pattern*,
  # yielding the matched string for each match.
  def scan(pattern : String)
    return self if pattern.empty?
    index = 0
    while index = byte_index(pattern, index)
      yield pattern
      index += pattern.bytesize
    end
    self
  end

  # Searches the string for instances of *pattern*,
  # returning an array of the matched string for each match.
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
  #   char # => 'a', 'b', '☃'
  # end
  # ```
  def each_char
    if ascii_only?
      each_byte do |byte|
        yield byte.unsafe_chr
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
  # chars.next # => 'a'
  # chars.next # => 'b'
  # chars.next # => '☃'
  # ```
  def each_char
    CharIterator.new(Char::Reader.new(self))
  end

  # Yields each character and its index in the string to the block.
  #
  # ```
  # "ab☃".each_char_with_index do |char, index|
  #   char  # => 'a', 'b', '☃'
  #   index # => 0,   1,   2
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
  # "ab☃".chars # => ['a', 'b', '☃']
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
  #   codepoint # => 97, 98, 9731
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
  # codepoints.next # => 97
  # codepoints.next # => 98
  # codepoints.next # => 9731
  # ```
  def each_codepoint
    each_char.map &.ord
  end

  # Returns an array of the codepoints that make the string. See Char#ord
  #
  # ```
  # "ab☃".codepoints # => [97, 98, 9731]
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
  #   byte # => 97, 98, 226, 152, 131
  # end
  # ```
  def each_byte
    to_unsafe.to_slice(bytesize).each do |byte|
      yield byte
    end
    self
  end

  # Returns an iterator over each byte in the string.
  #
  # ```
  # bytes = "ab☃".each_byte
  # bytes.next # => 97
  # bytes.next # => 98
  # bytes.next # => 226
  # bytes.next # => 156
  # bytes.next # => 131
  # ```
  def each_byte
    to_slice.each
  end

  # Returns this string's bytes as an `Array(UInt8)`.
  #
  # ```
  # "hello".bytes # => [104, 101, 108, 108, 111]
  # "你好".bytes    # => [228, 189, 160, 229, 165, 189]
  # ```
  def bytes
    Array.new(bytesize) { |i| to_unsafe[i] }
  end

  def inspect(io)
    dump_or_inspect(io) do |char|
      inspect_char(char, io)
    end
  end

  def pretty_print(pp)
    pp.text(inspect)
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
    if char.ascii_control?
      io << "\\u{"
      char.ord.to_s(16, io)
      io << "}"
    else
      io << char
    end
  end

  private def dump_char(char, io)
    if char.ascii_control? || char.ord >= 0x80
      io << "\\u{"
      char.ord.to_s(16, io)
      io << "}"
    else
      io << char
    end
  end

  def starts_with?(str : String)
    return false if str.bytesize > bytesize
    to_unsafe.memcmp(str.to_unsafe, str.bytesize) == 0
  end

  def starts_with?(char : Char)
    each_char do |c|
      return c == char
    end

    false
  end

  def ends_with?(str : String)
    return false if str.bytesize > bytesize
    (to_unsafe + bytesize - str.bytesize).memcmp(str.to_unsafe, str.bytesize) == 0
  end

  def ends_with?(char : Char)
    return false unless bytesize > 0

    if char.ascii? || ascii_only?
      return to_unsafe[bytesize - 1] == char.ord
    end

    bytes, count = String.char_bytes_and_bytesize(char)
    return false if bytesize < count

    count.times do |i|
      return false unless to_unsafe[bytesize - count + i] == bytes[i]
    end

    true
  end

  # Interpolates *other* into the string using `Kernel#sprintf`
  #
  # ```
  # "Party like it's %d!!!" % 1999 # => Party like it's 1999!!!
  # ```
  def %(other)
    sprintf self, other
  end

  # Returns a hash based on this string’s size and content.
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
  # "hello".size # => 5
  # "你好".size    # => 2
  # ```
  def size
    if @length > 0 || @bytesize == 0
      return @length
    end

    @length = each_byte_index_and_char_index { }
  end

  def ascii_only?
    @bytesize == size
  end

  protected def size_known?
    @bytesize == 0 || @length > 0
  end

  protected def each_byte_index_and_char_index
    byte_index = 0
    char_index = 0

    while byte_index < bytesize
      yield byte_index, char_index

      c = to_unsafe[byte_index]

      if c < 0x80
        byte_index += 1
      elsif c < 0xe0
        byte_index += 2
      elsif c < 0xf0
        byte_index += 3
      else
        byte_index += 4
      end

      char_index += 1
    end

    char_index
  end

  def to_slice
    Slice.new(to_unsafe, bytesize)
  end

  def clone
    self
  end

  def dup
    self
  end

  def to_s
    self
  end

  def to_s(io)
    io.write_utf8 Slice.new(to_unsafe, bytesize)
  end

  def to_unsafe
    pointerof(@c)
  end

  def unsafe_byte_slice(byte_offset, count)
    Slice.new(to_unsafe + byte_offset, count)
  end

  def unsafe_byte_slice(byte_offset)
    Slice.new(to_unsafe + byte_offset, bytesize - byte_offset)
  end

  protected def unsafe_byte_slice_string(byte_offset)
    String.new(unsafe_byte_slice(byte_offset))
  end

  protected def unsafe_byte_slice_string(byte_offset, count)
    String.new(unsafe_byte_slice(byte_offset, count))
  end

  protected def self.char_bytes_and_bytesize(char : Char)
    bytes = uninitialized UInt8[4]

    bytesize = 0
    char.each_byte do |byte|
      bytes[bytesize] = byte
      bytesize += 1
    end

    {bytes, bytesize}
  end

  private def range_to_index_and_size(range)
    from = range.begin
    from += size if from < 0
    raise IndexError.new if from < 0

    to = range.end
    to += size if to < 0
    to -= 1 if range.excludes_end?
    size = to - from + 1
    size = 0 if size < 0

    {from, size}
  end

  # Raises an `ArgumentError` if `self` has null bytes. Returns `self` otherwise.
  #
  # This method should sometimes be called before passing a String to a C function.
  def check_no_null_byte
    raise ArgumentError.new("string contains null byte") if byte_index(0)
    self
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

  private class CharIterator
    include Iterator(Char)

    @reader : Char::Reader
    @end : Bool

    def initialize(@reader, @end = false)
      check_empty
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
      check_empty
      self
    end

    private def check_empty
      @end = true if @reader.string.bytesize == 0
    end
  end

  private class LineIterator
    include Iterator(String)

    @string : String
    @offset : Int32
    @end : Bool

    def initialize(@string)
      @offset = 0
      @end = false
    end

    def next
      return stop if @end

      byte_index = @string.byte_index('\n'.ord.to_u8, @offset)
      if byte_index
        value = @string.unsafe_byte_slice_string(@offset, byte_index + 1 - @offset)
        @offset = byte_index + 1
      else
        if @offset == @string.bytesize
          value = stop
        else
          value = @string.unsafe_byte_slice_string(@offset)
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
