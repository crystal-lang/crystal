# A Char represents a [Unicode](http://en.wikipedia.org/wiki/Unicode) [code point](http://en.wikipedia.org/wiki/Code_point).
# It occupies 32 bits.
#
# It is created by enclosing an UTF-8 character in single quotes.
#
# ```text
# 'a'
# 'z'
# '0'
# '_'
# 'あ'
# ```
#
# You can use a backslash to denote some characters:
#
# ```text
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
# ```text
# '\101' # == 'A'
# '\123' # == 'S'
# '\12'  # == '\n'
# '\1'   # code point 1
# ```
#
# You can use a backslash followed by an u and four hexadecimal characters to denote a unicode codepoint written:
#
# ```text
# '\u0041' # == 'A'
# ```
#
# Or you can use curly braces and specify up to four hexadecimal numbers:
#
# ```text
# '\u{41}' # == 'A'
# ```
struct Char
  # The character representing the end of a C string.
  ZERO = '\0'

  # Returns the difference of the codepoint values of this char and `other`.
  #
  # ```
  # 'a' - 'a' #=> 0
  # 'b' - 'a' #=> 1
  # 'c' - 'a' #=> 2
  # ```
  def -(other : Char)
    ord - other.ord
  end

  # Implements the comparison operator for Char.
  #
  # ```
  # 'a' <=> 'c' #=> -2
  # ```
  def <=>(other : Char)
    self - other
  end

  # Returns true if this char is an ASCII digit ('0' to '9').
  #
  # ```
  # '4'.digit? #=> true
  # 'z'.digit? #=> false
  # ```
  def digit?
    '0' <= self && self <= '9'
  end

  # Returns true if this char is an ASCII letter ('a' to 'z', 'A' to 'Z').
  #
  # ```
  # 'c'.alpha? #=> true
  # '8'.alpha? #=> false
  # ```
  def alpha?
    ('a' <= self && self <= 'z') ||
      ('A' <= self && self <= 'Z')
  end

  # Returns true if this char is an ASCII letter or digit ('0' to '9', 'a' to 'z', 'A' to 'Z').
  #
  # ```
  # 'c'.alphanumeric? #=> true
  # '8'.alphanumeric? #=> true
  # '.'.alphanumeric? #=> false
  # ```
  def alphanumeric?
    alpha? || digit?
  end

  # Returns true if this char is an ASCII whitespace.
  #
  # ```
  # ' '.whitespace?  #=> true
  # '\t'.whitespace? #=> true
  # 'b'.whitespace?  #=> false
  # ```
  def whitespace?
    self == ' ' || 9 <= ord <= 13
  end

  # Returns the ASCII downcase equivalent of this char.
  #
  # ```
  # 'Z'.downcase #=> 'z'
  # 'x'.downcase #=> 'x'
  # '.'.downcase #=> '.'
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
  # 'z'.upcase #=> 'Z'
  # 'X'.upcase #=> 'X'
  # '.'.upcase #=> '.'
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
  # 'a'.succ #=> 'b'
  # 'あ'.succ #=> 'ぃ'
  # ```
  #
  # This method allows creating a `Range` of chars.
  def succ
    (ord + 1).chr
  end

  # Returns true if this char is an ASCII control character.
  #
  # ```
  # ('\u0000'..'\u0019').each do |char|
  #   char.control? #=> true
  # end
  #
  # ('\u007F'..'\u009F').each do |char|
  #   char.control? #=> true
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
  # 'a'.inspect      #=> "'a'"
  # '\t'.inspect     #=> "'\t'"
  # 'あ'.inspect     #=> "'あ'"
  # '\u0012'.inspect #=> "'\u{12}'"
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

  # Appens this Char as a String that contains a char literal as written in Crystal to the given IO.
  #
  # See `#inspect`.
  def inspect(io)
    io << inspect
  end

  # Returns this Char as a String that contains a char literal as written in Crystal,
  # with characters with a codepoint greater than 0x79 written as `\u{...}`.
  #
  # ```
  # 'a'.dump      #=> "'a'"
  # '\t'.dump     #=> "'\t'"
  # 'あ'.dump     #=> "'\u{3042}'"
  # '\u0012'.dump #=> "'\u{12}'"
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

  # Appens this Char as a String that contains a char literal as written in Crystal to the given IO.
  #
  # See `#dump`.
  def dump(io)
    io << '\''
    io << dump
    io << '\''
  end

  private def dump_or_inspect
    case self
    when '\''  then "'\\''"
    when '\\'  then "'\\\\'"
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
  # '1'.to_i #=> 1
  # '8'.to_i #=> 8
  # 'c'.to_i #=> 0
  # ```
  def to_i
    to_i { 0 }
  end

  # Returns the integer value of this char if it's an ASCII char denoting a digit,
  # otherwise the value returned by the block.
  #
  # ```
  # '1'.to_i { 10 } #=> 1
  # '8'.to_i { 10 } #=> 8
  # 'c'.to_i { 10 } #=> 10
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
  # '1'.to_i(16)     #=> 1
  # 'a'.to_i(16)     #=> 10
  # 'f'.to_i(16)     #=> 15
  # 'z'.to_i(16)     #=> 0
  # 'z'.to_i(16, 20) #=> 20
  # ```
  #
  # **Note**: the only bases supported right now are 10 and 16.
  def to_i(base, or_else = 0)
    to_i(base) { or_else }
  end

  # Returns the integer value of this char if it's an ASCII char denoting a digit in the given base,
  # otherwise the value return by the block.
  #
  # ```
  # '1'.to_i(16) { 20 } #=> 1
  # 'a'.to_i(16) { 20 } #=> 10
  # 'f'.to_i(16) { 20 } #=> 15
  # 'z'.to_i(16) { 20 } #=> 20
  # ```
  #
  # **Note**: the only bases supported right now are 10 and 16.
  def to_i(base)
    case base
    when 10
      to_i { yield }
    when 16
      if '0' <= self <= '9'
        self - '0'
      elsif 'a' <= self <= 'f'
        10 + (self - 'a')
      elsif 'A' <= self <= 'F'
        10 + (self - 'A')
      else
        yield
      end
    else
      raise "Unsupported base: #{base}"
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

  # Returns this Char bytes as encoded by UTF-8, as an `Array(UInt8)`.
  #
  # ```
  # 'a'.bytes #=> [97]
  # 'あ'.bytes #=> [227, 129, 130]
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
  # 'a'.to_s #=> "'a'"
  # 'あ'.to_s #=> "'あ'"
  # ```
  def to_s
    String.new(4) do |buffer|
      appender = buffer.appender
      each_byte { |byte| appender << byte }
      appender << 0_u8
      {appender.count - 1, 1}
    end
  end

  # Appens this Char to the given IO. This appens this Char's bytes as encoded
  # by UTF-8 to the given IO.
  def to_s(io : IO)
    if ord <= 0x7f
      io.write_byte ord.to_u8
    else
      chars :: UInt8[4]
      i = 0
      each_byte do |byte|
        chars[i] = byte
        i += 1
      end
      io.write chars.to_slice, i
    end
  end
end
