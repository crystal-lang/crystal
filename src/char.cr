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

  def to_s
    buffer = String::Buffer.new(4)
    buffer << self
    buffer.to_s
  end
end
