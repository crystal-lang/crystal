struct Char
  def ==(other : Int)
    ord == other
  end

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

  def inspect
    "'#{dump}'"
  end

  def dump
    case self
    when '\''  then "\\'"
    when '\f' then "\\f"
    when '\n' then "\\n"
    when '\r' then "\\r"
    when '\t' then "\\t"
    when '\v' then "\\v"
    else
      if ord < 32 || ord > 127
        high = ord / 16
        low = ord % 16
        high = high < 10 ? ('0'.ord + high).chr : ('A'.ord + high - 10).chr
        low = low < 10 ? ('0'.ord + low).chr : ('A'.ord + low - 10).chr
        "\\x#{high}#{low}"
      else
        self.to_s
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

  def to_i(base)
    to_i(base) { 0 }
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
      i = 0
      each_byte do |byte|
        buffer[i] = byte
        i += 1
      end
      buffer[i] = 0_u8
      i
    end
  end
end
