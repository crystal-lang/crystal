module Base64
  extend self

  class Error < Exception; end

  CHARS_STD  = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  CHARS_SAFE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
  LINE_SIZE = 60
  PAD = '='.ord.to_u8
  NL = '\n'.ord.to_u8
  NR = '\r'.ord.to_u8

  class Error < Exception; end

  def encode64(data)
    slice = data.to_slice
    String.new(encode_size(slice.length, true)) do |buf|
      inc = 0
      appender = buf.appender
      to_base64(slice, CHARS_STD, true) do |byte|
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
    slice = data.to_slice
    String.new(encode_size(slice.length)) do |buf|
      appender = buf.appender
      to_base64(slice, CHARS_STD, true) { |byte| appender << byte }
      count = appender.count
      {count, count}
    end
  end

  def urlsafe_encode64(data, padding = false)
    slice = data.to_slice
    String.new(encode_size(slice.length)) do |buf|
      appender = buf.appender
      to_base64(slice, CHARS_SAFE, padding) { |byte| appender << byte }
      count = appender.count
      {count, count}
    end
  end

  def decode64(data)
    slice = data.to_slice
    String.new(decode_size(slice.length)) do |buf|
      appender = buf.appender
      from_base64(slice) { |byte| appender << byte }
      {appender.count, 0}
    end
  end

  def strict_decode64(str)
    decode64(str)
  end

  def urlsafe_decode64(str)
    decode64(str)
  end

  private def encode_size(str_size, new_lines = false)
    size = (str_size * 4 / 3.0).to_i + 4
    size += size / LINE_SIZE if new_lines
    size
  end

  private def decode_size(str_size)
    (str_size * 3 / 4.0).to_i + 4
  end

  private def to_base64(data, chars, pad = false)
    bytes = chars.cstr
    len = data.length
    cstr = data.pointer(len)
    endcstr = cstr + len - len % 3
    while cstr < endcstr
      n = Intrinsics.bswap32((cstr as UInt32*).value)
      yield bytes[(n >> 26) & 63]
      yield bytes[(n >> 20) & 63]
      yield bytes[(n >> 14) & 63]
      yield bytes[(n >> 8) & 63]
      cstr += 3
    end

    pd = len % 3
    if pd == 1
      n = (cstr.value.to_u32 << 16)
      yield bytes[(n >> 18) & 63]
      yield bytes[(n >> 12) & 63]
      if pad
        yield PAD
        yield PAD
      end
    elsif pd == 2
      n = (cstr.value.to_u32 << 16) | ((cstr + 1).value.to_u32 << 8)
      yield bytes[(n >> 18) & 63]
      yield bytes[(n >> 12) & 63]
      yield bytes[(n >> 6) & 63]
      yield PAD if pad
    end
  end

  private def from_base64(data)
    len = data.length
    dt = DECODE_TABLE.buffer
    cstr = data.pointer(len)
    while (len > 0) && (sym = cstr[len - 1]) && (sym == NL || sym == NR || sym == PAD)
      len -= 1
    end
    endcstr = cstr + len - 4

    while true
      break if cstr > endcstr
      while cstr.value == NL || cstr.value == NR
        cstr += 1
      end

      break if cstr > endcstr
      a, b, c, d = next_decoded_value, next_decoded_value, next_decoded_value, next_decoded_value

      yield (a << 2 | b >> 4).to_u8
      yield (b << 4 | c >> 2).to_u8
      yield (c << 6 | d).to_u8
    end

    mod = (endcstr - cstr) % 4
    if mod == 2
      a, b = next_decoded_value, next_decoded_value
      yield (a << 2 | b >> 4).to_u8
    elsif mod == 3
      a, b, c = next_decoded_value, next_decoded_value, next_decoded_value
      yield (a << 2 | b >> 4).to_u8
      yield (b << 4 | c >> 2).to_u8
    elsif mod != 0
      raise Error.new("Wrong length")
    end
  end

  private macro next_decoded_value
    sym = cstr.value
    res = dt[sym]
    cstr += 1
    if res < 0
      raise Error.new("Unexpected symbol '#{sym.chr}'")
    end
    res
  end

  DECODE_TABLE = Array(Int8).new(256) do |i|
    case i.chr
    when 'A'..'Z'   then (i - 0x41).to_i8
    when 'a'..'z'   then (i - 0x47).to_i8
    when '0'..'9'   then (i + 0x04).to_i8
    when '+', '-'   then 0x3E_i8
    when '/', '_'   then 0x3F_i8
    else                 -1_i8
    end
  end
end
