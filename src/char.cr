require "comparable"

# A `Char` represents a [Unicode](http://en.wikipedia.org/wiki/Unicode) [code point](http://en.wikipedia.org/wiki/Code_point).
# It occupies 32 bits.
#
# It is created by enclosing an UTF-8 character in single quotes.
#
# ```
# 'a'
# 'z'
# '0'
# '_'
# 'あ'
# ```
#
# You can use a backslash to denote some characters:
#
# ```
# '\'' # single quote
# '\\' # backslash
# '\e' # escape
# '\f' # form feed
# '\n' # newline
# '\r' # carriage return
# '\t' # tab
# '\v' # vertical tab
# ```
#
# You can use a backslash followed by at most three digits to denote a code point written in octal:
#
# ```
# '\101' # == 'A'
# '\123' # == 'S'
# '\12'  # == '\n'
# '\1'   # code point 1
# ```
#
# You can use a backslash followed by an *u* and four hexadecimal characters to denote a unicode codepoint written:
#
# ```
# '\u0041' # == 'A'
# ```
#
# Or you can use curly braces and specify up to four hexadecimal numbers:
#
# ```
# '\u{41}' # == 'A'
# ```
struct Char
  include Comparable(Char)

  # The character representing the end of a C string.
  ZERO = '\0'

  # The maximum character.
  MAX = 0x10ffff.unsafe_chr

  # The maximum valid codepoint for a character.
  MAX_CODEPOINT = 0x10ffff

  # The replacement character, used on invalid utf-8 byte sequences
  REPLACEMENT = '\ufffd'

  # Returns the difference of the codepoint values of this char and *other*.
  #
  # ```
  # 'a' - 'a' # => 0
  # 'b' - 'a' # => 1
  # 'c' - 'a' # => 2
  # ```
  def -(other : Char)
    ord - other.ord
  end

  # Concatenates this char and *string*.
  #
  # ```
  # 'f' + "oo" # => "foo"
  # ```
  def +(str : String)
    bytesize = str.bytesize + self.bytesize
    String.new(bytesize) do |buffer|
      count = 0
      each_byte do |byte|
        buffer[count] = byte
        count += 1
      end

      (buffer + count).copy_from(str.to_unsafe, str.bytesize)

      {bytesize, str.size + 1}
    end
  end

  # Returns a char that has this char's codepoint plus *other*.
  #
  # ```
  # 'a' + 1 # => 'b'
  # 'a' + 2 # => 'c'
  # ```
  def +(other : Int) : Char
    (ord + other).chr
  end

  # Returns a char that has this char's codepoint minus *other*.
  #
  # ```
  # 'c' - 1 # => 'b'
  # 'c' - 2 # => 'a'
  # ```
  def -(other : Int) : Char
    (ord - other).chr
  end

  # Implements the comparison operator.
  #
  # ```
  # 'a' <=> 'c' # => -2
  # ```
  def <=>(other : Char)
    self - other
  end

  # Returns `true` if this char is an ASCII character
  # (codepoint is in (0..127))
  def ascii?
    ord < 128
  end

  # Returns `true` if this char is an ASCII number in specified base.
  #
  # Base can be from 0 to 36 with digits from '0' to '9' and 'a' to 'z' or 'A' to 'Z'.
  #
  # ```
  # '4'.ascii_number?     # => true
  # 'z'.ascii_number?     # => false
  # 'z'.ascii_number?(36) # => true
  # ```
  def ascii_number?(base : Int = 10)
    !!to_i?(base)
  end

  # Returns `true` if this char is a number according to unicode.
  #
  # ```
  # '1'.number? # => true
  # 'a'.number? # => false
  # ```
  def number?
    ascii? ? ascii_number? : Unicode.number?(self)
  end

  # Returns `true` if this char is a lowercase ASCII letter.
  #
  # ```
  # 'c'.ascii_lowercase? # => true
  # 'ç'.lowercase?       # => true
  # 'G'.ascii_lowercase? # => false
  # '.'.ascii_lowercase? # => false
  # ```
  def ascii_lowercase?
    'a' <= self <= 'z'
  end

  # Returns `true` if this char is a lowercase letter.
  #
  # ```
  # 'c'.lowercase? # => true
  # 'ç'.lowercase? # => true
  # 'G'.lowercase? # => false
  # '.'.lowercase? # => false
  # ```
  def lowercase?
    ascii? ? ascii_lowercase? : Unicode.lowercase?(self)
  end

  # Returns `true` if this char is an ASCII uppercase letter.
  #
  # ```
  # 'H'.ascii_uppercase? # => true
  # 'Á'.ascii_uppercase? # => false
  # 'c'.ascii_uppercase? # => false
  # '.'.ascii_uppercase? # => false
  # ```
  def ascii_uppercase?
    'A' <= self <= 'Z'
  end

  # Returns `true` if this char is an uppercase letter.
  #
  # ```
  # 'H'.uppercase? # => true
  # 'Á'.uppercase? # => true
  # 'c'.uppercase? # => false
  # '.'.uppercase? # => false
  # ```
  def uppercase?
    ascii? ? ascii_uppercase? : Unicode.uppercase?(self)
  end

  # Returns `true` if this char is an ASCII letter ('a' to 'z', 'A' to 'Z').
  #
  # ```
  # 'c'.ascii_letter? # => true
  # 'á'.ascii_letter? # => false
  # '8'.ascii_letter? # => false
  # ```
  def ascii_letter?
    ascii_lowercase? || ascii_uppercase?
  end

  # Returns `true` if this char is a letter.
  #
  # ```
  # 'c'.letter? # => true
  # 'á'.letter? # => true
  # '8'.letter? # => false
  # ```
  def letter?
    ascii? ? ascii_letter? : Unicode.letter?(self)
  end

  # Returns `true` if this char is an ASCII letter or number ('0' to '9', 'a' to 'z', 'A' to 'Z').
  #
  # ```
  # 'c'.ascii_alphanumeric? # => true
  # '8'.ascii_alphanumeric? # => true
  # '.'.ascii_alphanumeric? # => false
  # ```
  def ascii_alphanumeric?
    ascii_letter? || ascii_number?
  end

  # Returns `true` if this char is a letter or a number according to unicode.
  #
  # ```
  # 'c'.alphanumeric? # => true
  # '8'.alphanumeric? # => true
  # '.'.alphanumeric? # => false
  # ```
  def alphanumeric?
    letter? || number?
  end

  # Returns `true` if this char is an ASCII whitespace.
  #
  # ```
  # ' '.ascii_whitespace?  # => true
  # '\t'.ascii_whitespace? # => true
  # 'b'.ascii_whitespace?  # => false
  # ```
  def ascii_whitespace?
    self == ' ' || 9 <= ord <= 13
  end

  # Returns `true` if this char is a whitespace according to unicode.
  #
  # ```
  # ' '.whitespace?  # => true
  # '\t'.whitespace? # => true
  # 'b'.whitespace?  # => false
  # ```
  def whitespace?
    ascii? ? ascii_whitespace? : Unicode.whitespace?(self)
  end

  # Returns `true` if this char is an ASCII hex digit ('0' to '9', 'a' to 'z', 'A' to 'Z').
  #
  # ```
  # '5'.hex? # => true
  # 'a'.hex? # => true
  # 'F'.hex? # => true
  # 'g'.hex? # => false
  # ```
  def hex?
    ascii_number? 16
  end

  # Returns `true` if this char is matched by the given *sets*.
  #
  # Each parameter defines a set, the character is matched against
  # the intersection of those, in other words it needs to
  # match all sets.
  #
  # If a set starts with a ^, it is negated. The sequence c1-c2
  # means all characters between and including c1 and c2
  # and is known as a range.
  #
  # The backslash character \ can be used to escape ^ or - and
  # is otherwise ignored unless it appears at the end of a range
  # or the end of a a set.
  #
  # ```
  # 'l'.in_set? "lo"          # => true
  # 'l'.in_set? "lo", "o"     # => false
  # 'l'.in_set? "hello", "^l" # => false
  # 'l'.in_set? "j-m"         # => true
  #
  # '^'.in_set? "\\^aeiou" # => true
  # '-'.in_set? "a\\-eo"   # => true
  #
  # '\\'.in_set? "\\"    # => true
  # '\\'.in_set? "\\A"   # => false
  # '\\'.in_set? "X-\\w" # => true
  # ```
  def in_set?(*sets : String)
    if sets.size > 1
      return sets.all? { |set| in_set?(set) }
    end

    set = sets.first
    not_negated = true
    range = false
    previous = nil

    set.each_char do |char|
      case char
      when '^'
        unless previous # beginning of set
          not_negated = false
          previous = char
          next
        end
      when '-'
        if previous && previous != '\\'
          range = true

          if previous == '^' # ^- at the beginning
            previous = '^'
            not_negated = true
          end

          next
        else # at the beginning of the set or escaped
          return not_negated if self == char
        end
      end

      if range && previous
        raise ArgumentError.new "Invalid range #{previous}-#{char}" if previous > char

        return not_negated if previous <= self <= char

        range = false
      elsif char != '\\'
        return not_negated if self == char
      end

      previous = char
    end

    return not_negated if range && self == '-'
    return not_negated if previous == '\\' && self == previous

    !not_negated
  end

  # Returns the downcase equivalent of this char.
  #
  # Note that this only works for characters whose downcase
  # equivalent yields a single codepoint. There are a few
  # characters, like 'İ', than when downcased result in multiple
  # characters (in this case: 'I' and the dot mark).
  #
  # For a more correct method see the method that receives a block.
  #
  # ```
  # 'Z'.downcase # => 'z'
  # 'x'.downcase # => 'x'
  # '.'.downcase # => '.'
  # ```
  def downcase(options = Unicode::CaseOptions::None)
    Unicode.downcase(self, options)
  end

  # Yields each char for the downcase equivalent of this char.
  #
  # This method takes into account the possibility that an downcase
  # version of a char might result in multiple chars, like for
  # 'İ', which results in 'i' and a dot mark.
  def downcase(options = Unicode::CaseOptions::None)
    Unicode.downcase(self, options) { |char| yield char }
  end

  # Returns the upcase equivalent of this char.
  #
  # Note that this only works for characters whose upcase
  # equivalent yields a single codepoint. There are a few
  # characters, like 'ﬄ', than when upcased result in multiple
  # characters (in this case: 'F', 'F', 'L').
  #
  # For a more correct method see the method that receives a block.
  #
  # ```
  # 'z'.upcase # => 'Z'
  # 'X'.upcase # => 'X'
  # '.'.upcase # => '.'
  # ```
  def upcase(options = Unicode::CaseOptions::None)
    Unicode.upcase(self, options)
  end

  # Yields each char for the upcase equivalent of this char.
  #
  # This method takes into account the possibility that an upcase
  # version of a char might result in multiple chars, like for
  # 'ﬄ', which results in 'F', 'F' and 'L'.
  #
  # ```
  # 'z'.upcase { |v| puts v } # prints 'Z'
  # 'ﬄ'.upcase { |v| puts v } # prints 'F', 'F', 'L'
  # ```
  def upcase(options = Unicode::CaseOptions::None)
    Unicode.upcase(self, options) { |char| yield char }
  end

  # See `Object#hash(hasher)`
  def hash(hasher)
    hasher.char(self)
  end

  # Returns a Char that is one codepoint bigger than this char's codepoint.
  #
  # ```
  # 'a'.succ # => 'b'
  # 'あ'.succ # => 'ぃ'
  # ```
  #
  # This method allows creating a `Range` of chars.
  def succ
    (ord + 1).chr
  end

  # Returns a Char that is one codepoint smaller than this char's codepoint.
  #
  # ```
  # 'b'.pred # => 'a'
  # 'ぃ'.pred # => 'あ'
  # ```
  def pred
    (ord - 1).chr
  end

  # Returns `true` if this char is an ASCII control character.
  #
  # ```
  # ('\u0000'..'\u0019').each do |char|
  #   char.control? # => true
  # end
  #
  # ('\u007F'..'\u009F').each do |char|
  #   char.control? # => true
  # end
  # ```
  def ascii_control?
    ord < 0x20 || (0x7F <= ord <= 0x9F)
  end

  # Returns `true` if this char is a control character according to unicode.
  def control?
    ascii? ? ascii_control? : Unicode.control?(self)
  end

  # Returns `true` if this is char is a mark character according to unicode.
  def mark?
    Unicode.mark?(self)
  end

  # Returns this char as a string that contains a char literal.
  #
  # ```
  # 'a'.inspect      # => "'a'"
  # '\t'.inspect     # => "'\\t'"
  # 'あ'.inspect      # => "'あ'"
  # '\u0012'.inspect # => "'\\u{12}'"
  # ```
  def inspect
    dump_or_inspect do |io|
      if ascii_control?
        io << "\\u{"
        ord.to_s(16, io)
        io << "}"
      else
        to_s(io)
      end
    end
  end

  # Appends this char as a string that contains a char literal to the given `IO`.
  #
  # See also: `#inspect`.
  def inspect(io)
    io << inspect
  end

  # Returns this char as a string that contains a char literal as written in Crystal,
  # with characters with a codepoint greater than `0x79` written as `\u{...}`.
  #
  # ```
  # 'a'.dump      # => "'a'"
  # '\t'.dump     # => "'\\t'"
  # 'あ'.dump      # => "'\\u{3042}'"
  # '\u0012'.dump # => "'\\u{12}'"
  # ```
  def dump
    dump_or_inspect do |io|
      if ascii_control? || ord >= 0x80
        io << "\\u{"
        ord.to_s(16, io)
        io << "}"
      else
        to_s(io)
      end
    end
  end

  # Appends this char as a string that contains a char literal to the given `IO`.
  #
  # See also: `#dump`.
  def dump(io)
    io << '\''
    io << dump
    io << '\''
  end

  private def dump_or_inspect
    case self
    when '\'' then "'\\''"
    when '\\' then "'\\\\'"
    when '\e' then "'\\e'"
    when '\f' then "'\\f'"
    when '\n' then "'\\n'"
    when '\r' then "'\\r'"
    when '\t' then "'\\t'"
    when '\v' then "'\\v'"
    else
      String.build do |io|
        io << '\''
        yield io
        io << '\''
      end
    end
  end

  # Returns the integer value of this char if it's an ASCII char denoting a digit
  # in *base*, raises otherwise.
  #
  # ```
  # '1'.to_i     # => 1
  # '8'.to_i     # => 8
  # 'c'.to_i     # raises ArgumentError
  # '1'.to_i(16) # => 1
  # 'a'.to_i(16) # => 10
  # 'f'.to_i(16) # => 15
  # 'z'.to_i(16) # raises ArgumentError
  # ```
  def to_i(base : Int = 10) : Int32
    to_i?(base) || raise ArgumentError.new("Invalid integer: #{self}")
  end

  # Returns the integer value of this char if it's an ASCII char denoting a digit
  # in *base*, `nil` otherwise.
  #
  # ```
  # '1'.to_i     # => 1
  # '8'.to_i     # => 8
  # 'c'.to_i     # raises ArgumentError
  # '1'.to_i(16) # => 1
  # 'a'.to_i(16) # => 10
  # 'f'.to_i(16) # => 15
  # 'z'.to_i(16) # raises ArgumentError
  # ```
  def to_i?(base : Int = 10) : Int32?
    raise ArgumentError.new "Invalid base #{base}, expected 2 to 36" unless 2 <= base <= 36

    if base == 10
      return unless '0' <= self <= '9'
      self - '0'
    else
      ord = ord()
      if 0 <= ord < 256
        digit = String::CHAR_TO_DIGIT.to_unsafe[ord]
        return if digit == -1 || digit >= base
        digit.to_i32
      end
    end
  end

  # Same as `to_i`.
  def to_i32(base : Int = 10) : Int32
    to_i(base)
  end

  # Same as `to_i?`.
  def to_i32?(base : Int = 10) : Int32?
    to_i?(base)
  end

  {% for type in %w(i8 i16 i64 u8 u16 u32 u64) %}
    # See also: `to_i`.
    def to_{{type.id}}(base : Int = 10)
      to_i(base).to_{{type.id}}
    end

    # See also: `to_i?`.
    def to_{{type.id}}?(base : Int = 10)
      to_i?(base).try &.to_{{type.id}}
    end
  {% end %}

  # Returns the integer value of this char as a float if it's an ASCII char denoting a digit,
  # raises otherwise.
  #
  # ```
  # '1'.to_i # => 1.0
  # '8'.to_i # => 8.0
  # 'c'.to_i # raises ArgumentError
  # ```
  def to_f
    to_f64
  end

  # Returns the integer value of this char as a float if it's an ASCII char denoting a digit,
  # `nil` otherwise.
  #
  # ```
  # '1'.to_i # => 1.0
  # '8'.to_i # => 8.0
  # 'c'.to_i # raises ArgumentError
  # ```
  def to_f?
    to_f64?
  end

  # See also: `to_f`.
  def to_f32
    to_i.to_f32
  end

  # See also: `to_f?`.
  def to_f32?
    to_i?.try &.to_f32
  end

  # Same as `to_f`.
  def to_f64
    to_i.to_f64
  end

  # Same as `to_f?`.
  def to_f64?
    to_i?.try &.to_f64
  end

  # Yields each of the bytes of this char as encoded by UTF-8.
  #
  # ```
  # puts "'a'"
  # 'a'.each_byte do |byte|
  #   puts byte
  # end
  # puts
  #
  # puts "'あ'"
  # 'あ'.each_byte do |byte|
  #   puts byte
  # end
  # ```
  #
  # Output:
  #
  # ```text
  # 'a'
  # 97
  #
  # 'あ'
  # 227
  # 129
  # 130
  # ```
  def each_byte : Nil
    # See http://en.wikipedia.org/wiki/UTF-8#Sample_code

    c = ord
    if c < 0x80
      # 0xxxxxxx
      yield c.to_u8
    elsif c <= 0x7ff
      # 110xxxxx  10xxxxxx
      yield (0xc0 | c >> 6).to_u8
      yield (0x80 | c & 0x3f).to_u8
    elsif c <= 0xffff
      # 1110xxxx  10xxxxxx  10xxxxxx
      yield (0xe0 | (c >> 12)).to_u8
      yield (0x80 | ((c >> 6) & 0x3f)).to_u8
      yield (0x80 | (c & 0x3f)).to_u8
    elsif c <= MAX_CODEPOINT
      # 11110xxx  10xxxxxx  10xxxxxx  10xxxxxx
      yield (0xf0 | (c >> 18)).to_u8
      yield (0x80 | ((c >> 12) & 0x3f)).to_u8
      yield (0x80 | ((c >> 6) & 0x3f)).to_u8
      yield (0x80 | (c & 0x3f)).to_u8
    else
      raise InvalidByteSequenceError.new("Invalid char value #{dump}")
    end
  end

  # Returns the number of UTF-8 bytes in this char.
  #
  # ```
  # 'a'.bytesize # => 1
  # '好'.bytesize # => 3
  # ```
  def bytesize
    # See http://en.wikipedia.org/wiki/UTF-8#Sample_code

    c = ord
    if c < 0x80
      # 0xxxxxxx
      1
    elsif c <= 0x7ff
      # 110xxxxx  10xxxxxx
      2
    elsif c <= 0xffff
      # 1110xxxx  10xxxxxx  10xxxxxx
      3
    elsif c <= MAX_CODEPOINT
      # 11110xxx  10xxxxxx  10xxxxxx  10xxxxxx
      4
    else
      raise InvalidByteSequenceError.new("Invalid char value #{dump}")
    end
  end

  # Returns this char bytes as encoded by UTF-8, as an `Array(UInt8)`.
  #
  # ```
  # 'a'.bytes # => [97]
  # 'あ'.bytes # => [227, 129, 130]
  # ```
  def bytes
    bytes = [] of UInt8
    each_byte do |byte|
      bytes << byte
    end
    bytes
  end

  # Returns this char as a string containing this char as a single character.
  #
  # ```
  # 'a'.to_s # => "a"
  # 'あ'.to_s # => "あ"
  # ```
  def to_s
    String.new(4) do |buffer|
      appender = buffer.appender
      each_byte { |byte| appender << byte }
      {appender.size, 1}
    end
  end

  # Appends this char to the given `IO`.
  #
  # This appends this char's bytes as encoded by UTF-8 to the given `IO`.
  def to_s(io : IO)
    if ascii?
      byte = ord.to_u8

      # Optimization: writing a slice is much slower than writing a byte
      if io.@encoding
        io.write_utf8 Slice.new(pointerof(byte), 1)
      else
        io.write_byte byte
      end
    else
      chars = uninitialized UInt8[4]
      i = 0
      each_byte do |byte|
        chars[i] = byte
        i += 1
      end
      io.write_utf8 chars.to_slice[0, i]
    end
  end

  # Returns `true` if the codepoint is equal to *byte* ignoring the type.
  #
  # ```
  # 'c'.ord       # => 99
  # 'c' === 99_u8 # => true
  # 'c' === 99    # => true
  # 'z' === 99    # => false
  # ```
  def ===(byte : Int)
    ord === byte
  end

  def clone
    self
  end
end
