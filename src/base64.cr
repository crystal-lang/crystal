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

  # Writes the base64-encoded version of *data* to *io*.
  # This method complies with [RFC 2045](https://tools.ietf.org/html/rfc2045).
  # Line feeds are added to every 60 encoded characters.
  #
  # ```
  # Base64.encode("Now is the time for all good coders\nto learn Crystal", STDOUT)
  # ```
  def encode(data, io : IO)
    count = 0
    encode_with_new_lines(data.to_slice) do |byte|
      io << byte.unsafe_chr
      count += 1
    end
    io.flush
    count
  end

  private def encode_with_new_lines(data, &)
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

  # Writes the base64-encoded version of *data* with no newlines to *io*.
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
      io << byte.unsafe_chr
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

  # Writes the base64-encoded version of *data* using a urlsafe alphabet to *io*.
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
    appender.to_slice
  end

  # Writes the base64-decoded version of *data* to *io*.
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
    size += size // LINE_SIZE if new_lines
    size
  end

  private def decode_size(str_size)
    (str_size * 3 / 4.0).to_i + 4
  end

  private def to_base64(data, chars, pad = false, &)
    bytes = chars.to_unsafe
    size = data.size
    cstr = data.to_unsafe
    return if cstr.null? || size == 0
    endcstr = cstr + size - size % 3 - 3

    # process bunch of full triples
    while cstr < endcstr
      n = cstr.as(UInt32*).value.byte_swap
      yield bytes[(n >> 26) & 63]
      yield bytes[(n >> 20) & 63]
      yield bytes[(n >> 14) & 63]
      yield bytes[(n >> 8) & 63]
      cstr += 3
    end

    # process last full triple manually, because reading UInt32 not correct for guarded memory
    if size >= 3
      n = (cstr.value.to_u32 << 16) | ((cstr + 1).value.to_u32 << 8) | (cstr + 2).value
      yield bytes[(n >> 18) & 63]
      yield bytes[(n >> 12) & 63]
      yield bytes[(n >> 6) & 63]
      yield bytes[(n) & 63]
      cstr += 3
    end

    # process last partial triple
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

  # Processes the given data and yields each byte.
  private def from_base64(data : Bytes, &block : UInt8 -> Nil)
    size = data.size
    bytes = data.to_unsafe
    bytes_begin = bytes

    # Get the position of the last valid base64 character (rstrip '\n', '\r' and '=')
    while (size > 0) && (sym = bytes[size - 1]) && sym.in?(NL, NR, PAD)
      size -= 1
    end

    # Process combinations of four characters until there aren't any left
    fin = bytes + size - 4
    while true
      break if bytes > fin

      # Move the pointer by one byte until there is a valid base64 character
      while bytes.value.in?(NL, NR)
        bytes += 1
      end
      break if bytes > fin

      yield_decoded_chunk_bytes(bytes[0], bytes[1], bytes[2], bytes[3], chunk_pos: bytes - bytes_begin)
      bytes += 4
    end

    # Move the pointer by one byte until there is a valid base64 character or the end of `bytes` was reached
    while (bytes < fin + 4) && bytes.value.in?(NL, NR)
      bytes += 1
    end

    # If the amount of base64 characters is not divisible by 4, the remainder of the previous loop is handled here
    unread_bytes = (fin - bytes) % 4
    case unread_bytes
    when 1
      raise Base64::Error.new("Wrong size")
    when 2
      yield_decoded_chunk_bytes(bytes[0], bytes[1], chunk_pos: bytes - bytes_begin)
    when 3
      yield_decoded_chunk_bytes(bytes[0], bytes[1], bytes[2], chunk_pos: bytes - bytes_begin)
    end
  end

  # This macro decodes the given chunk of (2-4) base64 characters.
  # The argument chunk_pos is only used for the resulting error message.
  # The resulting bytes are then each yielded.
  private macro yield_decoded_chunk_bytes(*bytes, chunk_pos)
    %buffer = 0_u32
    {% for byte, i in bytes %}
      %decoded = DECODE_TABLE.unsafe_fetch({{ byte }})
      %buffer = (%buffer << 6) + %decoded
      raise Base64::Error.new("Unexpected byte 0x#{{{ byte }}.to_s(16)} at #{{{ chunk_pos }} + {{ i }}}") if %decoded == 255_u8
    {% end %}

    # Each byte in the buffer is shifted to rightmost position of the buffer, then casted to a UInt8
    {% for i in 2..(bytes.size) %}
      yield (%buffer >> {{ (4 - bytes.size) * 2 + (8 * (bytes.size - i)) }}).to_u8!
    {% end %}
  end

  private DECODE_TABLE = Array(UInt8).new(size: 256) do |i|
    case i.unsafe_chr
    when 'A'..'Z' then (i - 0x41).to_u8!
    when 'a'..'z' then (i - 0x47).to_u8!
    when '0'..'9' then (i + 0x04).to_u8!
    when '+', '-' then 0x3E_u8
    when '/', '_' then 0x3F_u8
    else               255_u8
    end
  end
end
