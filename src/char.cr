# A Char represents a [Unicode](http://en.wikipedia.org/wiki/Unicode) [code point](http://en.wikipedia.org/wiki/Code_point).
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
  # The character representing the end of a C string.
  ZERO = '\0'

  # Returns the difference of the codepoint values of this char and `other`.
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
    bytesize = str.bytesize + bytesize
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

  # Implements the comparison operator.
  #
  # ```
  # 'a' <=> 'c' # => -2
  # ```
  #
  # See `Object#<=>`
  def <=>(other : Char)
    self - other
  end

  # Returns true if this char is an ASCII digit ('0' to '9').
  #
  # ```
  # '4'.digit? # => true
  # 'z'.digit? # => false
  # ```
  def digit?
    '0' <= self && self <= '9'
  end

  # Returns true if this char is an ASCII letter ('a' to 'z', 'A' to 'Z').
  #
  # ```
  # 'c'.alpha? # => true
  # '8'.alpha? # => false
  # ```
  def alpha?
    ('a' <= self && self <= 'z') ||
      ('A' <= self && self <= 'Z')
  end

  # Returns true if this char is an ASCII letter or digit ('0' to '9', 'a' to 'z', 'A' to 'Z').
  #
  # ```
  # 'c'.alphanumeric? # => true
  # '8'.alphanumeric? # => true
  # '.'.alphanumeric? # => false
  # ```
  def alphanumeric?
    alpha? || digit?
  end

  # Returns true if this char is an ASCII whitespace.
  #
  # ```
  # ' '.whitespace?  # => true
  # '\t'.whitespace? # => true
  # 'b'.whitespace?  # => false
  # ```
  def whitespace?
    self == ' ' || 9 <= ord <= 13
  end

  # Returns true if this char is matched by the given sets.
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

  # Returns the ASCII downcase equivalent of this char.
  #
  # ```
  # 'Z'.downcase # => 'z'
  # 'x'.downcase # => 'x'
  # '.'.downcase # => '.'
  # ```
  def downcase
    if 'A' <= self && self <= 'Z'
      (self.ord + 32).chr
    else
      self
    end
  end

  # Returns the ASCII upcase equivalent of this char.
  #
  # ```
  # 'z'.upcase # => 'Z'
  # 'X'.upcase # => 'X'
  # '.'.upcase # => '.'
  # ```
  def upcase
    if 'a' <= self && self <= 'z'
      (self.ord - 32).chr
    else
      self
    end
  end

  # Returns this char's codepoint.
  def hash
    ord
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

  # Returns true if this char is an ASCII control character.
  #
  # ```
  # ('\u0000'..'\u0019').each do |char|
  #   char.control? # => true
  # end
  #
  # ('\u007F'..'\u009F').each do |char|
  #   char.control? # => true
  # end
  #
  # # false in every other case
  # ```
  def control?
    ord < 0x20 || (0x7F <= ord <= 0x9F)
  end

  # Returns this Char as a String that contains a char literal as written in Crystal.
  #
  # ```
  # 'a'.inspect      # => "'a'"
  # '\t'.inspect     # => "'\t'"
  # 'あ'.inspect      # => "'あ'"
  # '\u0012'.inspect # => "'\u{12}'"
  # ```
  def inspect
    dump_or_inspect do |io|
      if control?
        io << "\\u{"
        ord.to_s(16, io)
        io << "}"
      else
        to_s(io)
      end
    end
  end

  # Appends this Char as a String that contains a char literal as written in Crystal to the given IO.
  #
  # See `#inspect`.
  def inspect(io)
    io << inspect
  end

  # Returns this Char as a String that contains a char literal as written in Crystal,
  # with characters with a codepoint greater than 0x79 written as `\u{...}`.
  #
  # ```
  # 'a'.dump      # => "'a'"
  # '\t'.dump     # => "'\t'"
  # 'あ'.dump      # => "'\u{3042}'"
  # '\u0012'.dump # => "'\u{12}'"
  # ```
  def dump
    dump_or_inspect do |io|
      if control? || ord >= 0x80
        io << "\\u{"
        ord.to_s(16, io)
        io << "}"
      else
        to_s(io)
      end
    end
  end

  # Appends this Char as a String that contains a char literal as written in Crystal to the given IO.
  #
  # See `#dump`.
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

  # Returns the integer value of this char if it's an ASCII char denoting a digit,
  # 0 otherwise.
  #
  # ```
  # '1'.to_i # => 1
  # '8'.to_i # => 8
  # 'c'.to_i # => 0
  # ```
  def to_i
    to_i { 0 }
  end

  # Returns the integer value of this char if it's an ASCII char denoting a digit,
  # otherwise the value returned by the block.
  #
  # ```
  # '1'.to_i { 10 } # => 1
  # '8'.to_i { 10 } # => 8
  # 'c'.to_i { 10 } # => 10
  # ```
  def to_i
    if '0' <= self <= '9'
      self - '0'
    else
      yield
    end
  end

  # Returns the integer value of this char if it's an ASCII char denoting a digit in the given base,
  # otherwise the value of `or_else`.
  #
  # ```
  # '1'.to_i(16)     # => 1
  # 'a'.to_i(16)     # => 10
  # 'f'.to_i(16)     # => 15
  # 'z'.to_i(16)     # => 0
  # 'z'.to_i(16, 20) # => 20
  # ```
  def to_i(base, or_else = 0)
    to_i(base) { or_else }
  end

  # Returns the integer value of this char if it's an ASCII char denoting a digit in the given base,
  # otherwise the value return by the block.
  #
  # ```
  # '1'.to_i(16) { 20 } # => 1
  # 'a'.to_i(16) { 20 } # => 10
  # 'f'.to_i(16) { 20 } # => 15
  # 'z'.to_i(16) { 20 } # => 20
  # ```
  def to_i(base)
    raise ArgumentError.new "invalid base #{base}" unless 2 <= base <= 36

    ord = ord()
    if ord < 256
      digit = String::CHAR_TO_DIGIT.to_unsafe[ord]
      if digit == -1 || digit >= base
        return yield
      end
      digit
    else
      return yield
    end
  end

  # Yields each of the bytes of this Char as encoded by UTF-8.
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
  def each_byte
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
    elsif c <= 0x10ffff
      # 11110xxx  10xxxxxx  10xxxxxx  10xxxxxx
      yield (0xf0 | (c >> 18)).to_u8
      yield (0x80 | ((c >> 12) & 0x3f)).to_u8
      yield (0x80 | ((c >> 6) & 0x3f)).to_u8
      yield (0x80 | (c & 0x3f)).to_u8
    else
      raise "Invalid char value"
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
    elsif c <= 0x10ffff
      # 11110xxx  10xxxxxx  10xxxxxx  10xxxxxx
      4
    else
      raise "Invalid char value"
    end
  end

  # Returns this Char bytes as encoded by UTF-8, as an `Array(UInt8)`.
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

  # Returns this Char as a String containing this Char as a single character.
  #
  # ```
  # 'a'.to_s # => "a"
  # 'あ'.to_s # => "あ"
  # ```
  def to_s
    String.new(4) do |buffer|
      appender = buffer.appender
      each_byte { |byte| appender << byte }
      appender << 0_u8
      {appender.size - 1, 1}
    end
  end

  # Appends this Char to the given IO. This appends this Char's bytes as encoded
  # by UTF-8 to the given IO.
  def to_s(io : IO)
    if ord <= 0x7f
      byte = ord.to_u8
      io.write_utf8 Slice.new(pointerof(byte), 1)
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

  def ===(byte : Int)
    ord === byte
  end
end
