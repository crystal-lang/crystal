# The `Base64` module provides for the encoding (`encode`, `strict_encode`,
# `urlsafe_encode`) and decoding (`decode`)
# of binary data using a base64 representation.
#
# ### Example
#
# A simple encoding and decoding.
#
# ```
# require "base64"
#
# enc = Base64.encode("Send reinforcements") # => "U2VuZCByZWluZm9yY2VtZW50cw==\n"
# plain = Base64.decode_string(enc)          # => "Send reinforcements"
# ```
#
# The purpose of using base64 to encode data is that it translates any binary
# data into purely printable characters.
module Base64
  extend self

  class Error < Exception; end

  private CHARS_STD  = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  private CHARS_SAFE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
  private LINE_SIZE  = 60
  private PAD        = '='.ord.to_u8
  private NL         = '\n'.ord.to_u8
  private NR         = '\r'.ord.to_u8

  # Returns the base64-encoded version of *data*.
  # This method complies with [RFC 2045](https://tools.ietf.org/html/rfc2045).
  # Line feeds are added to every 60 encoded characters.
  #
  # ```
  # puts Base64.encode("Now is the time for all good coders\nto learn Crystal")
  # ```
  #
  # Generates:
  #
  # ```text
  # Tm93IGlzIHRoZSB0aW1lIGZvciBhbGwgZ29vZCBjb2RlcnMKdG8gbGVhcm4g
  # Q3J5c3RhbA==
  # ```
  def encode(data) : String
    slice = data.to_slice
    String.new(encode_size(slice.size, new_lines: true)) do |buf|
      appender = buf.appender
      encode_with_new_lines(slice) { |byte| appender << byte }
      size = appender.size
      {size, size}
    end
  end

  # Write the base64-encoded version of *data* to *io*.
  # This method complies with [RFC 2045](https://tools.ietf.org/html/rfc2045).
  # Line feeds are added to every 60 encoded characters.
  #
  # ```
  # Base64.encode("Now is the time for all good coders\nto learn Crystal", STDOUT)
  # ```
  def encode(data, io : IO)
    count = 0
    encode_with_new_lines(data.to_slice) do |byte|
      io.write_byte byte
      count += 1
    end
    io.flush
    count
  end

  private def encode_with_new_lines(data)
    inc = 0
    to_base64(data.to_slice, CHARS_STD, pad: true) do |byte|
      yield byte
      inc += 1
      if inc >= LINE_SIZE
        yield NL
        inc = 0
      end
    end
    if inc > 0
      yield NL
    end
  end

  # Returns the base64-encoded version of *data* with no newlines.
  # This method complies with [RFC 4648](https://tools.ietf.org/html/rfc4648).
  #
  # ```
  # puts Base64.strict_encode("Now is the time for all good coders\nto learn Crystal")
  # ```
  #
  # Generates:
  #
  # ```text
  # Tm93IGlzIHRoZSB0aW1lIGZvciBhbGwgZ29vZCBjb2RlcnMKdG8gbGVhcm4gQ3J5c3RhbA==
  # ```
  def strict_encode(data) : String
    strict_encode data, CHARS_STD, pad: true
  end

  private def strict_encode(data, alphabet, pad = false)
    slice = data.to_slice
    String.new(encode_size(slice.size)) do |buf|
      appender = buf.appender
      to_base64(slice, alphabet, pad: pad) { |byte| appender << byte }
      size = appender.size
      {size, size}
    end
  end

  # Write the base64-encoded version of *data* with no newlines to *io*.
  # This method complies with [RFC 4648](https://tools.ietf.org/html/rfc4648).
  #
  # ```
  # Base64.strict_encode("Now is the time for all good coders\nto learn Crystal", STDOUT)
  # ```
  def strict_encode(data, io : IO)
    strict_encode_to_io_internal(data, io, CHARS_STD, pad: true)
  end

  private def strict_encode_to_io_internal(data, io, alphabet, pad)
    count = 0
    to_base64(data.to_slice, alphabet, pad: pad) do |byte|
      count += 1
      io.write_byte byte
    end
    io.flush
    count
  end

  # Returns the base64-encoded version of *data* using a urlsafe alphabet.
  # This method complies with "Base 64 Encoding with URL and Filename Safe
  # Alphabet" in [RFC 4648](https://tools.ietf.org/html/rfc4648).
  #
  # The alphabet uses `'-'` instead of `'+'` and `'_'` instead of `'/'`.
  #
  # The *padding* parameter defaults to `true`. When `false`, enough `=` characters
  # are not added to make the output divisible by 4.
  def urlsafe_encode(data, padding = true) : String
    slice = data.to_slice
    String.new(encode_size(slice.size)) do |buf|
      appender = buf.appender
      to_base64(slice, CHARS_SAFE, pad: padding) { |byte| appender << byte }
      size = appender.size
      {size, size}
    end
  end

  # Write the base64-encoded version of *data* using a urlsafe alphabet to *io*.
  # This method complies with "Base 64 Encoding with URL and Filename Safe
  # Alphabet" in [RFC 4648](https://tools.ietf.org/html/rfc4648).
  #
  # The alphabet uses `'-'` instead of `'+'` and `'_'` instead of `'/'`.
  def urlsafe_encode(data, io : IO)
    strict_encode_to_io_internal(data, io, CHARS_SAFE, pad: true)
  end

  # Returns the base64-decoded version of *data* as a `Bytes`.
  # This will decode either the normal or urlsafe alphabets.
  def decode(data) : Bytes
    slice = data.to_slice
    buf = Pointer(UInt8).malloc(decode_size(slice.size))
    appender = buf.appender
    from_base64(slice) { |byte| appender << byte }
    Slice.new(buf, appender.size.to_i32)
  end

  # Write the base64-decoded version of *data* to *io*.
  # This will decode either the normal or urlsafe alphabets.
  def decode(data, io : IO)
    count = 0
    from_base64(data.to_slice) do |byte|
      io.write_byte byte
      count += 1
    end
    io.flush
    count
  end

  # Returns the base64-decoded version of *data* as a string.
  # This will decode either the normal or urlsafe alphabets.
  def decode_string(data) : String
    slice = data.to_slice
    String.new(decode_size(slice.size)) do |buf|
      appender = buf.appender
      from_base64(slice) { |byte| appender << byte }
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
      n = Intrinsics.bswap32(cstr.as(UInt32*).value)
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

  private def from_base64(data)
    size = data.size
    dt = DECODE_TABLE.to_unsafe
    cstr = data.pointer(size)
    start_cstr = cstr
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

    while (cstr < endcstr + 4) && (cstr.value == NL || cstr.value == NR)
      cstr += 1
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

  private macro next_decoded_value
    sym = cstr.value
    res = dt[sym]
    cstr += 1
    if res < 0
      raise Error.new("Unexpected byte 0x#{sym.to_s(16)} at #{cstr - start_cstr - 1}")
    end
    res
  end

  private DECODE_TABLE = Array(Int8).new(256) do |i|
    case i.unsafe_chr
    when 'A'..'Z' then (i - 0x41).to_i8
    when 'a'..'z' then (i - 0x47).to_i8
    when '0'..'9' then (i + 0x04).to_i8
    when '+', '-' then 0x3E_i8
    when '/', '_' then 0x3F_i8
    else               -1_i8
    end
  end
end
