struct Char
  ZERO = '\0'

  def -(other : Char)
    ord - other.ord
  end

  def digit?
    '0' <= self && self <= '9'
  end

  def alpha?
    ('a' <= self && self <= 'z') ||
      ('A' <= self && self <= 'Z')
  end

  def alphanumeric?
    alpha? || digit?
  end

  def whitespace?
    self == ' ' || 9 <= ord <= 13
  end

  def downcase
    if 'A' <= self && self <= 'Z'
      (self.ord + 32).chr
    else
      self
    end
  end

  def upcase
    if 'a' <= self && self <= 'z'
      (self.ord - 32).chr
    else
      self
    end
  end

  def hash
    ord
  end

  def succ
    (ord + 1).chr
  end

  def control?
    ord < 0x20 || (0x7F <= ord <= 0x9F)
  end

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

  def inspect(io)
    io << inspect
  end

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

  def to_i
    to_i { 0 }
  end

  def to_i
    if '0' <= self <= '9'
      self - '0'
    else
      yield
    end
  end

  def to_i(base, or_else = 0)
    to_i(base) { or_else }
  end

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

  def each_byte
    c = ord
    if c <= 0x7f
      # 0xxxxxxx
      yield c.to_u8
    elsif c <= 0x7ff
      # 110xxxxx  10xxxxxx
      yield (0xc0 | c >> 6).to_u8
      yield (0x80 | c & 0x3f).to_u8
    elsif c <= 0xffff
      # 1110xxxx  10xxxxxx  10xxxxxx
      yield (0xe0 | c >> 12).to_u8
      yield (0x80 | c >> 6 & 0x3f).to_u8
      yield (0x80 | c & 0x3f).to_u8
    elsif c <= 0x1fffff
      # 11110xxx  10xxxxxx  10xxxxxx  10xxxxxx
      yield (0xf0 | c >> 18).to_u8
      yield (0x80 | c >> 12 & 0x3f).to_u8
      yield (0x80 | c >> 6 & 0x3f).to_u8
      yield (0x80 | c & 0x3f).to_u8
    else
      raise "Invalid char value"
    end
  end

  def to_s
    String.new_with_capacity_and_length(4) do |buffer|
      appender = buffer.appender
      each_byte { |byte| appender << byte }
      appender << 0_u8
      appender.count - 1
    end
  end

  def to_s(io : IO)
    chars :: UInt8[4]
    i = 0
    each_byte do |byte|
      chars[i] = byte
      i += 1
    end
    io.write chars.to_slice, i
  end
end
