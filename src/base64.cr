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

  # Writes the base64-decoded version of `from` into `to`,
  # and returns the amount of bytes written.
  #
  # If the `to` buffer is not big enough to store the resulting bytes,
  # or if the input is invalid base64, the method raises a `Base64::Error`.
  #
  # This will decode either the normal or urlsafe alphabets.
  def decode(from : Bytes, to : Bytes) : Int32
    total_written_bytes : Int32 = 0

    from_ptr = from.to_unsafe
    from_size = from.size
    to_ptr = to.to_unsafe
    to_size = to.size

    read_bytes, written_bytes = decode_buffer_regular(from_ptr, from_size, to_ptr, to_size)
    total_written_bytes &+= written_bytes
    from_ptr += read_bytes
    from_size &-= read_bytes
    to_ptr += written_bytes
    to_size &-= written_bytes

    if from_size > 0
      read_bytes, written_bytes = decode_buffer_final(from_ptr, from_size, to_ptr, to_size)
      total_written_bytes &+= written_bytes

      raise Base64::Error.new("Expected EOF but found non-decodable characters") if from_size > read_bytes
    end

    total_written_bytes
  end

  # Returns the base64-decoded version of `data` as a `Bytes`.
  #
  # Raises `Base64::Error` if the input is invalid base64.
  #
  # This will decode either the normal or urlsafe alphabets.
  def decode(data) : Bytes
    data = data.to_slice
    buf_size = decode_size(data.size)

    buffer = Bytes.new(buf_size)
    bytes_written = decode(from: data, to: buffer)
    buffer[0, bytes_written]
  end

  # Writes the base64-decoded version of `data` to `io`,
  # and returns the amount of bytes written.
  #
  # Raises `Base64::Error` if the input is invalid base64.
  #
  # This will decode either the normal or urlsafe alphabets.
  def decode(data, io : IO) : Int32
    total_written_bytes : Int32 = 0

    data = data.to_slice
    data_ptr = data.to_unsafe
    data_size = data.size

    buffer = uninitialized UInt8[IO::DEFAULT_BUFFER_SIZE]

    while true
      read_bytes, written_bytes = decode_buffer_regular(data_ptr, data_size, buffer.to_unsafe, buffer.size)
      total_written_bytes &+= written_bytes

      break if read_bytes == 0

      data_ptr += read_bytes
      data_size &-= read_bytes
      io.write(Bytes.new(buffer.to_unsafe, written_bytes))
    end

    if data_size > 0
      read_bytes, written_bytes = decode_buffer_final(data_ptr, data_size, buffer.to_unsafe, buffer.size)
      total_written_bytes &+= written_bytes

      io.write(Bytes.new(buffer.to_unsafe, written_bytes))

      raise Base64::Error.new("Expected EOF but found non-decodable characters") if data_size > read_bytes
    end

    io.flush
    total_written_bytes
  end

  # Writes the base64-decoded version of `from` into `to`.
  #
  # Raises `Base64::Error` if the input is invalid base64.
  #
  # This will decode either the normal or urlsafe alphabets.
  def decode(from : IO, to : IO) : Nil
    # Here the same buffer is used for in- and output.
    buffer = uninitialized UInt8[IO::DEFAULT_BUFFER_SIZE]
    in_size = 0
    in_offset = 0

    while true
      # Move still-present data inside the buffer to the beginning
      if in_size > 0 && in_offset > 0
        Intrinsics.memmove(buffer.to_unsafe, buffer.to_unsafe + in_offset, in_size, false)
      end

      # Fill the buffer
      bytes_copied = from.read(Slice.new(buffer.to_unsafe + in_size, buffer.size - in_size))
      in_size += bytes_copied

      # It is possible that an IO implementation could read less than 4 bytes into the buffer,
      # in which case the IO has not necessarily reached EOF (but decode_buffer_regular requires 4 bytes).
      if in_size < 4
        break if bytes_copied == 0
        next
      end

      read_bytes, written_bytes = decode_buffer_regular(buffer.to_unsafe, in_size, buffer.to_unsafe, buffer.size)
      in_offset = read_bytes
      in_size &-= read_bytes
      break if read_bytes == 0

      to.write(Bytes.new(buffer.to_unsafe, written_bytes))
    end

    while true
      # Move still-present data inside the buffer to the beginning
      if in_size > 0 && in_offset > 0
        Intrinsics.memmove(buffer.to_unsafe, buffer.to_unsafe + in_offset, in_size, false)
      end

      # Fill the buffer
      bytes_copied = from.read(Slice.new(buffer.to_unsafe + in_size, buffer.size - in_size))
      in_size += bytes_copied

      # It is possible that an IO implementation could read less than 4 bytes into the buffer,
      # in which case the IO has not necessarily reached EOF (but decode_buffer_final wants 4 bytes).
      if in_size < 4
        break if in_size == 0
        next unless bytes_copied == 0
      end

      read_bytes, written_bytes = decode_buffer_final(buffer.to_unsafe, in_size, buffer.to_unsafe, buffer.size)
      raise Base64::Error.new("Expected EOF but found non-decodable characters") if read_bytes == 0

      in_offset = read_bytes
      in_size &-= read_bytes
      to.write(Bytes.new(buffer.to_unsafe, written_bytes))
      break if written_bytes > 0
    end

    while true
      # Move still-present data inside the buffer to the beginning
      if in_size > 0 && in_offset > 0
        Intrinsics.memmove(buffer.to_unsafe, buffer.to_unsafe + in_offset, in_size, false)
      end

      # Fill the buffer
      bytes_copied = from.read(Slice.new(buffer.to_unsafe + in_size, buffer.size - in_size))
      in_size += bytes_copied
      break if in_size == 0

      read_bytes = consume_buffer_garbage(buffer.to_unsafe, in_size)
      raise Base64::Error.new("Expected EOF but found non-decodable characters") if read_bytes != in_size
      in_offset = read_bytes
      in_size &-= read_bytes
    end

    to.flush
  end

  # Returns the base64-decoded version of *data* as a string.
  # This will decode either the normal or urlsafe alphabets.
  def decode_string(data) : String
    data = data.to_slice
    buf_size = decode_size(data.size)

    String.new(buf_size) do |buf|
      bytes_written = decode(from: data, to: Bytes.new(buf, buf_size))
      {bytes_written, 0}
    end
  end

  private def encode_size(str_size, new_lines = false)
    size = (str_size * 4 / 3.0).to_i + 4
    size += size // LINE_SIZE if new_lines
    size
  end

  # Returns the maximum amount of bytes required to
  # decode a base64-buffer with the given bytesize
  private def decode_size(bytesize : Int::Primitive) : Int::Primitive
    chunks, remainder = bytesize.divmod(4)
    (chunks * 3) + ((remainder > 1) ? remainder - 1 : 0)
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

  # Decodes base64 data sequentially from the `in` buffer and writes it into the `out` buffer.
  #
  # This method only reads complete 4-character chunks (ex. "0ABC"),
  # not padding or non-4-character chunks (ex. "AB", "0AC=").
  # These must be read using `decode_base64_buffer_final`.
  #
  # Raises a `Base64::Error` when invalid characters are passed.
  #
  # Returns the amount of bytes read and the amount of bytes written.
  #
  # NOTE: This method expects the buffer used for decoding to fit at least four bytes.
  #       If the given buffer contains less than four bytes, this method will return without decoding.
  private def decode_buffer_regular(in_ptr : UInt8*, in_size : Int32, out_ptr : UInt8*, out_size : Int32) : Tuple(Int32, Int32)
    in_ptr_orig : UInt8* = in_ptr
    out_ptr_orig : UInt8* = out_ptr
    in_ptr_end : UInt8* = in_ptr + (Int64.new!(in_size) &- 4)
    out_ptr_end : UInt8* = out_ptr + (Int64.new!(out_size) &- 3)

    out_pos : Int32 = 0
    decode_ptr : UInt8* = DECODE_TABLE.to_unsafe

    while true
      # Move the pointer by one byte until there is a valid base64 character
      while in_ptr <= in_ptr_end && in_ptr.value.in?(10_u8, 13_u8)
        in_ptr += 1
      end

      break if in_ptr > in_ptr_end || out_ptr > out_ptr_end

      chunk : UInt32 = 0
      bytes_state : UInt8 = 0

      # Read and decode characters into `chunk`,
      # writing additional flags to `bytes_state`.
      current_byte = decode_ptr[in_ptr.value]
      chunk = (chunk << 6) &+ current_byte
      bytes_state |= current_byte
      in_ptr += 1
      current_byte = decode_ptr[in_ptr.value]
      chunk = (chunk << 6) &+ current_byte
      bytes_state |= current_byte
      in_ptr += 1
      current_byte = decode_ptr[in_ptr.value]
      chunk = (chunk << 6) &+ current_byte
      bytes_state |= current_byte
      in_ptr += 1
      current_byte = decode_ptr[in_ptr.value]
      chunk = (chunk << 6) &+ current_byte
      bytes_state |= current_byte
      in_ptr += 1

      raise Base64::Error.new("Invalid base64 chunk") if bytes_state >= 0x80_u8
      if bytes_state >= 0x40_u8
        in_ptr -= 4
        break
      end

      # Write resulting bytes
      out_ptr.value = (chunk >> 16).to_u8!
      out_ptr += 1
      out_ptr.value = (chunk >> 8).to_u8!
      out_ptr += 1
      out_ptr.value = chunk.to_u8!
      out_ptr += 1
    end

    {Int32.new!(in_ptr - in_ptr_orig), Int32.new!(out_ptr - out_ptr_orig)}
  end

  # Decodes base64 data from the `in` buffer and writes it into the `out` buffer.
  #
  # This method expects the buffer given via `in_ptr` and `in_size`
  # to contain exactly one encoding character (with optional padding at the end).
  #
  # Once this method has written at least one byte into the output buffer,
  # it may not be called again for the remaining part of the buffer.
  # For this, you can use `consume_buffer_garbage`.
  # That being said, note that there can only be a "remaining part of the buffer" if
  # not all relevant bytes have been given to `decode_buffer_final`.
  #
  # Raises a `Base64::Error` when invalid chunks/characters are passed.
  #
  # Returns the amount of bytes read and the amount of bytes written.
  #
  # NOTE: This method expects the buffer used for decoding to contain
  #       all decodable characters if there is no padding before it.
  #       If the given buffer contains only a part of the last chunk without padding,
  #       either an error is thrown or the output is cut off.
  private def decode_buffer_final(in_ptr : UInt8*, in_size : Int32, out_ptr : UInt8*, out_size : Int32) : Tuple(Int32, Int32)
    in_pos : Int32 = 0
    decode_ptr : UInt8* = DECODE_TABLE.to_unsafe

    # Move the pointer by one byte until there is a valid base64 character
    while in_pos < in_size && in_ptr.value.in?(10_u8, 13_u8)
      in_pos &+= 1
    end

    return {in_pos, 0} if in_size == in_pos
    raise Base64::Error.new("Invalid base64 chunk") if in_size &- in_pos == 1

    chunk : UInt32 = 0
    bytes_state : UInt8 = 0
    write_count : UInt8 = 1

    # Read and decode characters into `chunk`,
    # writing additional flags to `bytes_state`.
    current_byte = decode_ptr[in_ptr[in_pos]]
    chunk = (chunk << 6) &+ current_byte
    bytes_state |= current_byte
    in_pos &+= 1
    current_byte = decode_ptr[in_ptr[in_pos]]
    chunk = (chunk << 6) &+ current_byte
    bytes_state |= current_byte
    in_pos &+= 1
    chunk <<= 6
    if in_size > 2
      current_byte = decode_ptr[in_ptr[in_pos]]
      chunk = chunk &+ (current_byte & 0x3F)
      bytes_state |= current_byte & 0b10000000
      write_count &+= 1 if current_byte & 0b01000000 == 0
      in_pos &+= 1
    end
    chunk <<= 6
    if in_size > 3
      current_byte = decode_ptr[in_ptr[in_pos]]
      chunk = chunk &+ (current_byte & 0x3F)
      bytes_state |= current_byte & 0b10000000
      if current_byte & 0b01000000 == 0
        # Disallow decodable characters after a padding character.
        raise Base64::Error.new("Invalid base64 chunk") if write_count == 1
        write_count &+= 1
      end
      in_pos &+= 1
    end

    raise Base64::Error.new("Invalid base64 chunk") if bytes_state >= 0x80_u8

    return {0, 0} if write_count > out_size

    # Write resulting bytes
    out_ptr.value = (chunk >> 16).to_u8!
    out_ptr += 1
    if write_count > 1
      out_ptr.value = (chunk >> 8).to_u8!
      out_ptr += 1
    end
    if write_count > 2
      out_ptr.value = chunk.to_u8!
    end

    # Skip remaining allowed whitespace characters
    while in_pos < in_size && in_ptr[in_pos].in?(10_u8, 13_u8)
      in_pos &+= 1
    end

    {in_pos, write_count.to_i32!}
  end

  # Reads any allowed padding characters from the given buffer.
  #
  # If the amount of bytes read from the buffer does not equal
  # the amount of bytes in the given buffer,
  # a character in the buffer is not allowed at this position.
  private def consume_buffer_garbage(in_ptr : UInt8*, in_size : Int32) : Int32
    in_ptr_orig : UInt8* = in_ptr
    in_ptr_end : UInt8* = in_ptr + in_size

    # Skip remaining allowed whitespace characters
    while in_ptr < in_ptr_end && in_ptr.value.in?(10_u8, 13_u8)
      in_ptr += 1
    end

    Int32.new!(in_ptr - in_ptr_orig)
  end

  # The lookup table used for decoding the base64 bytes.
  #
  # The individual bytes inside the table are structured as follows:
  # - `0bX0000000`
  #   The first bit is the "invalidity flag".
  #   If a character must never appear inside a base64 string, this flag is set.
  # - `0b0X000000`
  #   The second bit is the "skip flag".
  #   If a character must be ignored (ex. "\r\n", "=" padding), this flag is set.
  # - `0b00XXXXXX`
  #   The last 6 bits are the decoded value of a valid base64 byte.
  #   If any of these bits are set, the first two bits are always `0b00`.
  private DECODE_TABLE = Array(UInt8).new(size: 256) do |i|
    case i.unsafe_chr
    when 'A'..'Z'        then (i - 0x41).to_u8!
    when 'a'..'z'        then (i - 0x47).to_u8!
    when '0'..'9'        then (i + 0x04).to_u8!
    when '+', '-'        then 0x3E_u8
    when '/', '_'        then 0x3F_u8
    when '=', '\n', '\r' then 0x40_u8
    else                      0x80_u8
    end
  end
end
