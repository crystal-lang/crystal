module Base64
  extend self

  CHARS_STD  = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  CHARS_SAFE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
  LINE_SIZE = 60
  PAD = '='.ord.to_u8
  NL = '\n'.ord.to_u8

  class Error < Exception; end

  def encode64(data)
    data = to_slice(data)
    String.new(encode_size(data.length, true)) do |buf|
      inc = 0
      appender = buf.appender
      to_base64(data, CHARS_STD, true) do |byte|
        appender << byte
        inc += 1
        if inc >= LINE_SIZE
          appender << NL
          inc = 0
        end
      end
      if inc > 0
        appender << NL
      end
      count = appender.count
      {count, count}
    end
  end

  def strict_encode64(data)
    data = to_slice(data)
    String.new(encode_size(data.length)) do |buf|
      appender = buf.appender
      to_base64(data, CHARS_STD, true) { |byte| appender << byte }
      count = appender.count
      {count, count}
    end
  end

  def urlsafe_encode64(data)
    data = to_slice(data)
    String.new(encode_size(data.length)) do |buf|
      appender = buf.appender
      to_base64(data, CHARS_SAFE, false) { |byte| appender << byte }
      count = appender.count
      {count, count}
    end
  end

  def decode64(data)
    data = to_slice(data)
    String.new(decode_size(data.length)) do |buf|
      appender = buf.appender
      from_base64(data) { |byte| appender << byte }
      {appender.count, 0}
    end
  end

  def strict_decode64(str)
    decode64(str)
  end

  def urlsafe_decode64(str)
    decode64(str)
  end

  private def to_slice(data : Slice(UInt8))
    data
  end

  private def to_slice(data : StaticArray(UInt8, N))
    data.to_slice
  end

  private def to_slice(data : String)
    Slice(UInt8).new(data.cstr, data.bytesize)
  end

  private def encode_size(str_size, new_lines = false)
    size = (str_size * 4 / 3.0).to_i + 6
    size += size / LINE_SIZE if new_lines
    size
  end

  private def decode_size(str_size)
    (str_size * 3 / 4.0).to_i + 6
  end

  private def to_base64(data, chars, pad = false)
    bytes = chars.cstr
    len = data.length
    cstr = data.pointer(len)
    i = 0
    while i < len - len % 3
      n = (cstr[i].to_u32 << 16) | (cstr[i + 1].to_u32 << 8) | (cstr[i + 2].to_u32)
      yield bytes[(n >> 18) & 63]
      yield bytes[(n >> 12) & 63]
      yield bytes[(n >> 6) & 63]
      yield bytes[(n) & 63]
      i += 3
    end

    pd = len % 3
    if pd == 1
      n = (cstr[i].to_u32 << 16)
      yield bytes[(n >> 18) & 63]
      yield bytes[(n >> 12) & 63]
      if pad
        yield PAD
        yield PAD
      end
    elsif pd == 2
      n = (cstr[i].to_u32 << 16) | (cstr[i + 1].to_u32 << 8)
      yield bytes[(n >> 18) & 63]
      yield bytes[(n >> 12) & 63]
      yield bytes[(n >> 6) & 63]
      yield PAD if pad
    end
  end

  private def from_base64(data)
    buf = 0
    mod = 0
    dt = DECODE_TABLE.buffer
    data.each do |byte|
      dec = dt[byte]
      if dec < 0
        next if dec == -2
        break if dec == -3
        raise Error.new("Invalid character '#{byte.chr}'")
      end
      buf = (buf | dec) << 6
      mod += 1
      if mod == 4
        mod = 0
        yield (buf >> 22).to_u8
        yield (buf >> 14).to_u8
        yield (buf >> 6).to_u8
      end
    end

    if mod == 2
      yield (buf >> 10).to_u8
    elsif mod == 3
      yield (buf >> 16).to_u8
      yield (buf >> 8).to_u8
    elsif mod != 0
      raise Error.new("Wrong length")
    end
  end

  DECODE_TABLE = Array.new(256) do |i|
    case i.chr
    when 'A'..'Z'   then i - 0x41
    when 'a'..'z'   then i - 0x47
    when '0'..'9'   then i + 0x04
    when '+', '-'   then 0x3E
    when '/', '_'   then 0x3F
    when '\n', '\r' then -2
    when '='        then -3
    else                 -1
    end
  end
end
