# The Base64 module provides for the encoding (`encode`, `strict_encode`,
# `urlsafe_encode`) and decoding (`decode`, `strict_decode`, `urlsafe_decode`)
# of binary data using a Base64 representation.
#
# ###Example
#
# A simple encoding and decoding.
#
#     require "base64"
#     enc   = Base64.encode("Send reinforcements")
#                         # => "U2VuZCByZWluZm9yY2VtZW50cw==\n"
#     plain = Base64.decode(enc)
#                         # => "Send reinforcements"
#
# The purpose of using base64 to encode data is that it translates any binary
# data into purely printable characters.
module Base64
  extend self

  class Error < Exception; end

  # :nodoc:
  CHARS_STD = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  # :nodoc:
  CHARS_SAFE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
  # :nodoc:
  LINE_SIZE = 60
  # :nodoc:
  PAD = '='.ord.to_u8
  # :nodoc:
  NL = '\n'.ord.to_u8
  # :nodoc:
  NR = '\r'.ord.to_u8

  class Error < Exception; end

  # Returns the Base64-encoded version of `data`.
  # This method complies with RFC 2045.
  # Line feeds are added to every 60 encoded characters.
  #
  #     require "base64"
  #     puts Base64.encode("Now is the time for all good coders\nto learn Crystal")
  #
  # Generates:
  #
  # ```text
  # Tm93IGlzIHRoZSB0aW1lIGZvciBhbGwgZ29vZCBjb2RlcnMKdG8gbGVhcm4g
  # ```
  def encode(data)
    slice = data.to_slice
    String.new(encode_size(slice.size, new_lines: true)) do |buf|
      inc = 0
      appender = buf.appender
      to_base64(slice, CHARS_STD, pad: true) do |byte|
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
      size = appender.size
      {size, size}
    end
  end

  # Returns the Base64-encoded version of `data` with no newlines.
  # This method complies with RFC 4648.
  #
  #     require "base64"
  #     puts Base64.strict_encode("Now is the time for all good coders\nto learn Crystal")
  #
  # Generates:
  #
  # ```text
  # Tm93IGlzIHRoZSB0aW1lIGZvciBhbGwgZ29vZCBjb2RlcnMKdG8gbGVhcm4gQ3J5c3RhbA==
  # ```
  def strict_encode(data)
    strict_encode data, CHARS_STD, pad: true
  end

  # :nodoc:
  def strict_encode(data, alphabet, pad = false)
    slice = data.to_slice
    String.new(encode_size(slice.size)) do |buf|
      appender = buf.appender
      to_base64(slice, alphabet, pad: pad) { |byte| appender << byte }
      size = appender.size
      {size, size}
    end
  end

  # Returns the Base64-encoded version of `data` using a urlsafe alphabet.
  # This method complies with "Base 64 Encoding with URL and Filename Safe
  # Alphabet" in RFC 4648.
  #
  # The alphabet uses '-' instead of '+' and '_' instead of '/'.
  #
  # The `padding` parameter defaults to false. When true, enough `=` characters
  # are added to make the output divisible by 3.
  def urlsafe_encode(data, padding = false)
    slice = data.to_slice
    String.new(encode_size(slice.size)) do |buf|
      appender = buf.appender
      to_base64(slice, CHARS_SAFE, pad: padding) { |byte| appender << byte }
      size = appender.size
      {size, size}
    end
  end

  # Returns the Base64-decoded version of `data` as a *Slice(UInt8)*.
  # This will decode either the normal or urlsafe alphabets.
  def decode(data)
    slice = data.to_slice
    buf = Pointer(UInt8).malloc(decode_size(slice.size))
    appender = buf.appender
    from_base64(slice, DECODE_TABLE) { |byte| appender << byte }
    Slice.new(buf, appender.size.to_i32)
  end

  # Returns the Base64-decoded version of `data` as a string.
  # If the data doesn't decode to a valid UTF8 string,
  # *InvalidByteSequenceError* will be raised.
  # This will decode either the normal or urlsafe alphabets.
  def decode_string(data)
    slice = data.to_slice
    String.new(decode_size(slice.size)) do |buf|
      appender = buf.appender
      from_base64(slice, DECODE_TABLE) { |byte| appender << byte }
      {appender.size, 0}
    end
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
    bytes = chars.to_unsafe
    size = data.size
    cstr = data.pointer(size)
    endcstr = cstr + size - size % 3
    while cstr < endcstr
      n = Intrinsics.bswap32((cstr as UInt32*).value)
      yield bytes[(n >> 26) & 63]
      yield bytes[(n >> 20) & 63]
      yield bytes[(n >> 14) & 63]
      yield bytes[(n >> 8) & 63]
      cstr += 3
    end

    pd = size % 3
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

  private def from_base64(data, decode_table)
    size = data.size
    dt = DECODE_TABLE.to_unsafe
    cstr = data.pointer(size)
    while (size > 0) && (sym = cstr[size - 1]) && (sym == NL || sym == NR || sym == PAD)
      size -= 1
    end
    endcstr = cstr + size - 4

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
      raise Error.new("Wrong size")
    end
  end

  # :nodoc:
  macro next_decoded_value
    sym = cstr.value
    res = dt[sym]
    cstr += 1
    if res < 0
      raise Error.new("Unexpected symbol '#{sym.chr}'")
    end
    res
  end

  # :nodoc:
  DECODE_TABLE = Array(Int8).new(256) do |i|
    case i.chr
    when 'A'..'Z' then (i - 0x41).to_i8
    when 'a'..'z' then (i - 0x47).to_i8
    when '0'..'9' then (i + 0x04).to_i8
    when '+', '-' then 0x3E_i8
    when '/', '_' then 0x3F_i8
    else               -1_i8
    end
  end
end
