# Bcrypt needs his own base64
# Note that this is *not* compatible with the standard MIME-base64 encoding.
module Bcrypt::Base64
  extend self

  ALPHABET = "./ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
  DECODE_TABLE = [
    0, 1,
    54, 55, 56, 57, 58, 59, 60, 61, 62, 63, -1, -1, -1, -1, -1, -1, -1,
    2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
    21, 22, 23, 24, 25, 26, 27, -1, -1, -1, -1, -1, -1, 28, 29, 30, 31,
    32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48,
    49, 50, 51, 52, 53, -1, -1, -1, -1, -1
  ]

  def encode64(data)
    slice = data.to_slice
    String.new(encode_size(slice.length)) do |buf|
      appender = buf.appender
      to_base64(slice, ALPHABET) { |byte| appender << byte }
      count = appender.count
      {count, count}
    end
  end

  def decode64(data)
    slice = data.to_slice

    String.new(encode_size(slice.length)) do |buf|
      appender = buf.appender
      from_base64(slice) { |byte| appender << byte }
      {appender.count, 0}
    end
  end

  private def encode_size(str_size)
    (str_size * 4 / 3.0).to_i + 1
  end 
  
  private def to_base64(data, chars)
    bytes = chars.cstr
    len = data.length
    len -= 1 if len > 16
    cstr = data.pointer(len)
    i = 0

    while i < len
      c1 = (cstr[i] & 0xff).to_u32
      i += 1
      yield bytes[c1 >> 2]

      c1 = (c1 & 0x03) << 4
      if (i >= len)
        yield bytes[c1]
        break
      end

      c2 = (cstr[i] & 0xff).to_u32
      i += 1
      c1 = c1 | c2 >> 4
      yield bytes[c1]

      c1 = (c2 & 0x0f) << 2
      if (i >= len)

        yield bytes[c1]
        break
      end

      c2 = (cstr[i] & 0xff).to_u32
      i += 1
      c1 = c1 | (c2 >> 6)
      yield bytes[c1]
      yield bytes[c2 & 0x3f]
    end
  end

  private def from_base64(data)
    i = 0
    while true
      c1 = DECODE_TABLE[data[i]-46]
      i += 1
      c2 = DECODE_TABLE[data[i]-46]
      i += 1
      yield ((c1 << 2 | c2 >> 4) & 0xff).to_u8

      break if (i == data.length)

      c1 = c2 << 4
      c2 = DECODE_TABLE[data[i]-46]
      i += 1
      yield ((c1 | c2 >> 2) & 0xff).to_u8

      c1 = c2 << 6
      c2 = DECODE_TABLE[data[i]-46]
      i += 1
      yield ((c1 | c2) & 0xff).to_u8
    end
  end
end
