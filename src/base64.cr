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
  private LINE_PAIRS = LINE_SIZE // 4
  private LINE_BYTES = LINE_PAIRS * 3
  private PAD        = '='
  private NL         = '\n'
  private NR         = '\r'

  {% begin %}
    private STREAM_MAX_INPUT_BUFFER_SIZE = {{ IO::DEFAULT_BUFFER_SIZE // (LINE_SIZE + 1) * (LINE_SIZE // 4 * 3) }}
  {% end %}

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

    encode_size = encode_size(slice.size, new_lines: true)
    String.new(encode_size) do |buf|
      bytes_written = encode_base64_buffer(slice, Bytes.new(buf, encode_size), CHARS_STD.to_unsafe.as(UInt8[64]*), newlines: true, pad: true)
      {bytes_written, bytes_written}
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
    slice = data.to_slice

    encode_size = encode_size(slice.size, new_lines: true)
    String.new(encode_size) do |buf|
      bytes_written = encode_base64_buffer(slice, Bytes.new(buf, encode_size), CHARS_STD.to_unsafe.as(UInt8[64]*), newlines: false, pad: true)
      {bytes_written, bytes_written}
    end
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

    encode_size = encode_size(slice.size, new_lines: true)
    String.new(encode_size) do |buf|
      bytes_written = encode_base64_buffer(slice, Bytes.new(buf, encode_size), CHARS_SAFE.to_unsafe.as(UInt8[64]*), newlines: false, pad: padding)
      {bytes_written, bytes_written}
    end
  end

  # Writes the base64-encoded version of *data* to *io*.
  # This method complies with [RFC 2045](https://tools.ietf.org/html/rfc2045).
  # Line feeds are added to every 60 encoded characters.
  #
  # ```
  # Base64.encode("Now is the time for all good coders\nto learn Crystal", STDOUT)
  # ```
  def encode(data, io : IO) : Int32
    slice = data.to_slice

    encode_base64_chunked(slice, CHARS_STD.to_unsafe.as(UInt8[64]*), newlines: true, pad: true) do |buf|
      io.write_string(buf)
    end.tap { io.flush }
  end

  # Writes the base64-encoded version of *data* with no newlines to *io*.
  # This method complies with [RFC 4648](https://tools.ietf.org/html/rfc4648).
  #
  # ```
  # Base64.strict_encode("Now is the time for all good coders\nto learn Crystal", STDOUT)
  # ```
  def strict_encode(data, io : IO) : Int32
    slice = data.to_slice

    encode_base64_chunked(slice, CHARS_STD.to_unsafe.as(UInt8[64]*), pad: true) do |buf|
      io.write_string(buf)
    end.tap { io.flush }
  end

  # Writes the base64-encoded version of *data* using a urlsafe alphabet to *io*.
  # This method complies with "Base 64 Encoding with URL and Filename Safe
  # Alphabet" in [RFC 4648](https://tools.ietf.org/html/rfc4648).
  #
  # The alphabet uses `'-'` instead of `'+'` and `'_'` instead of `'/'`.
  def urlsafe_encode(data, io : IO, padding = true) : Int32
    slice = data.to_slice

    encode_base64_chunked(slice, CHARS_SAFE.to_unsafe.as(UInt8[64]*), pad: padding) do |buf|
      io.write_string(buf)
    end.tap { io.flush }
  end

  # :nodoc:
  def encode(data : IO, io : IO) : Int64
    encode_base64_stream(data, io, CHARS_STD.to_unsafe.as(UInt8[64]*), newlines: true, pad: true)
  end

  # :nodoc:
  def strict_encode(data : IO, io : IO) : Int64
    encode_base64_stream(data, io, CHARS_STD.to_unsafe.as(UInt8[64]*), pad: true)
  end

  # :nodoc:
  def urlsafe_encode(data : IO, io : IO, padding = true) : Int64
    encode_base64_stream(data, io, CHARS_SAFE.to_unsafe.as(UInt8[64]*), pad: padding)
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

  private def encode_base64_stream(input : IO, output : IO, charset : UInt8[64]*, *, newlines : Bool = false, pad : Bool = false) : Int64
    input_buffer = uninitialized UInt8[STREAM_MAX_INPUT_BUFFER_SIZE]
    output_buffer = uninitialized UInt8[IO::DEFAULT_BUFFER_SIZE]
    total_written = 0

    while true
      # TODO: input_size = input.read_fully(input_buffer.to_slice)
      input_size = begin
        slice = input_buffer.to_slice

        count = slice.size
        while slice.size > 0
          read_bytes = input.read(slice)
          return count &- slice.size if read_bytes == 0
          slice += read_bytes
        end
        count
      end

      written = encode_base64_buffer(input_buffer[0, input_size], output_buffer.to_unsafe, charset, newlines: newlines, pad: pad)
      output.write_string(output_buffer.to_slice[0, written])
      total_written += written

      break if input_size != input_buffer.size
    end

    total_written
  end

  # Internal method for encoding bytes from one buffer as base64, using chunks allocated by this method.
  # Returns the amount of bytes written into output.
  private def encode_base64_chunked(
    input : Bytes, charset : UInt8[64]*, *, newlines : Bool = false, pad : Bool = false, & : Bytes -> Nil
  ) : Int32
    total_written = 0

    # Make sure output's size is a multiple of (LINE_SIZE + 1) and 4,
    # so we never cut-off pairs/lines in the middle of the output.
    output = uninitialized UInt8[IO::DEFAULT_BUFFER_SIZE]

    while input.size > 0
      process_bytes = Math.min(STREAM_MAX_INPUT_BUFFER_SIZE, input.size)
      written_bytes = encode_base64_buffer(input[0, process_bytes], output.to_slice, charset, newlines: newlines, pad: pad)

      input += process_bytes

      yield output.to_slice[0, written_bytes]
      total_written &+= written_bytes
    end

    total_written
  end

  # The internal base64 encoding implementation.
  #
  # All other base64-encoding methods use this method for the
  # actual encoding, so it should be optimized the most.
  #
  # For streaming base64 producers, care must be taken so only the last call
  # to this method may contain an amount of input bytes not divisible by 3
  # since the last base64 pair is handled in a special way.
  #
  # *charset* should be a 64-byte array containing the 64 characters used in the encoding.
  # Depending on the platform, it may be beneficial to align the charset on a cache boundary (align to 64 bytes).
  #
  # The *newlines* flag causes a newline character to be added
  # every 60 encoded base64 characters for RFC 2045 compliance.
  #
  # The *pad* flag causes equal signs to be added to the end of the encoded stream
  # so the amount of base64 characters is divisible by 4.
  #
  # The *extra_byte* flag tells the method that reading a single byte
  # outside of the valid range of input (= reading `input[input.size]`)
  # does not cause an invalid memory access.
  # This is intended to improve performance for streaming encoder implementations.
  private def encode_base64_buffer(input : Bytes, output : Bytes, charset : UInt8[64]*, *, newlines : Bool = false, pad : Bool = false, extra_byte : Bool = false) : Int32
    initial_output = output.to_unsafe

    # Handle large sections of data in chunks for performance.
    # This is the performance-critical section (for long inputs).
    while (input.size + (extra_byte ? 1 : 0)) > LINE_BYTES
      encode_base64_buffer__full_pairs_excess(input.to_unsafe, output.to_unsafe, LINE_PAIRS, charset)

      input += LINE_BYTES
      output += LINE_SIZE

      if newlines
        output[0] = NL.ord.to_u8!
        output += 1
      end
    end

    # Handle a trailing section of data.
    # Should only happen once for an entire encode for both streaming and string-based methods.
    unless input.empty?
      pairs, remaining_bytes = input.size.divmod(3)
      encode_base64_buffer__full_pairs(input.to_unsafe, output.to_unsafe, pairs, charset, max_pairs: LINE_PAIRS)
      input += pairs &* 3
      output += pairs &* 4

      if remaining_bytes > 0
        output += encode_base64_buffer__tail(input.to_unsafe, output.to_unsafe, remaining_bytes, charset, pad: pad)
      end

      if newlines
        output[0] = NL.ord.to_u8!
        output += 1
      end
    end

    (output.to_unsafe.address &- initial_output.address).to_i32!
  end

  # Internal method of encode_base64_buffer.
  #
  # On most archivectures supported by crystal, unaligned memory access is very cheap.
  # This section thus tries to improve performance by unrolling the loop and by replacing
  # three aligned UInt8 accesses by one unaligned UInt32 access (discarding the last byte).
  # The condition `pairs > 8` makes sure that there's at least one pair which is processed byte by byte,
  # so we never accidentally read one byte further than we're allowed to (-> possible segfault).
  #
  # NOTE: On weak-memory architectures like risc-v, llvm must replace the
  # unaligned UInt32 access by *four* aligned UInt8 accesses, degrading performance.
  #
  # NOTE: The method uses AlwaysInline so const *pairs* values result in an unrolled loop.
  @[AlwaysInline]
  private def encode_base64_buffer__full_pairs_excess(input : UInt8*, output : UInt8*, pairs : Int32, charset : UInt8[64]*) : Nil
    charset = charset.as(UInt8*)

    while pairs > 0
      value = 0_u32
      pointerof(value).as(UInt8*).copy_from(input, count: 4)
      input += 3

      value = value.byte_swap if IO::ByteFormat::SystemEndian == IO::ByteFormat::LittleEndian

      output[0] = charset[(value >> 26) & 63]
      output[1] = charset[(value >> 20) & 63]
      output[2] = charset[(value >> 14) & 63]
      output[3] = charset[(value >> 8) & 63]
      output += 4

      pairs &-= 1
    end
  end

  # Internal method of encode_base64_buffer.
  #
  # NOTE: The method's behaviour is undefined if `pairs > max_pairs`.
  #
  # NOTE: The method uses AlwaysInline so const *max_pairs* values result in an unrolled loop.
  @[AlwaysInline]
  private def encode_base64_buffer__full_pairs(input : UInt8*, output : UInt8*, pairs : Int32, charset : UInt8[64]*, *, max_pairs : Int32 = 8) : Nil
    Intrinsics.unreachable if pairs > max_pairs

    return if pairs <= 0

    if pairs > 1
      encode_base64_buffer__full_pairs_excess(input, output, pairs - 1, charset)
      input += 3 &* pairs
      output += 4 &* pairs
    end

    charset = charset.as(UInt8*)

    value = 0_u32
    pointerof(value).as(UInt8*).copy_from(input, count: 3)
    input += 3

    value = value.byte_swap if IO::ByteFormat::SystemEndian == IO::ByteFormat::LittleEndian

    output[0] = charset[(value >> 26) & 63]
    output[1] = charset[(value >> 20) & 63]
    output[2] = charset[(value >> 14) & 63]
    output[3] = charset[(value >> 8) & 63]
  end

  # Internal method of encode_base64_buffer.
  #
  # Base64-encodes the tail of a buffer (last 1-2 bytes) with or without padding.
  # Returns the amount of bytes written into output.
  # If `pad == `true`, exactly 4 bytes will be written to *output*.
  # Otherwise, `(input_size + 1)` bytes will be written to *output*.
  #
  # This method assumes that `1 <= input_size <= 2`.
  # Otherwise, the method's behaviour is undefined.
  private def encode_base64_buffer__tail(input : UInt8*, output : UInt8*, tailsize : Int32, charset : UInt8[64]*, *, pad : Bool = false) : Int32
    charset = charset.as(UInt8*)

    in0 = input[0]
    output[0] = charset[in0 >> 2]

    if tailsize == 1
      output[1] = charset[in0 << 6 >> 2]
      return 2 unless pad

      output[2] = PAD.ord.to_u8!
      output[3] = PAD.ord.to_u8!
    elsif tailsize == 2
      in1 = input[1]
      output[1] = charset[(in0 << 6 >> 2) | (in1 >> 4)]
      output[2] = charset[(in1 << 4 >> 2)]
      return 3 unless pad

      output[3] = PAD.ord.to_u8!
    else
      Intrinsics.unreachable
    end

    4
  end

  # Processes the given data and yields each byte.
  private def from_base64(data : Bytes, &block : UInt8 -> Nil)
    size = data.size
    bytes = data.to_unsafe
    bytes_begin = bytes

    # Get the position of the last valid base64 character (rstrip '\n', '\r' and '=')
    while (size > 0) && (sym = bytes[size - 1]) && sym.unsafe_chr.in?(NL, NR, PAD)
      size -= 1
    end

    # Process combinations of four characters until there aren't any left
    fin = bytes + size - 4
    while true
      break if bytes > fin

      # Move the pointer by one byte until there is a valid base64 character
      while bytes.value.unsafe_chr.in?(NL, NR)
        bytes += 1
      end
      break if bytes > fin

      yield_decoded_chunk_bytes(bytes[0], bytes[1], bytes[2], bytes[3], chunk_pos: bytes - bytes_begin)
      bytes += 4
    end

    # Move the pointer by one byte until there is a valid base64 character or the end of `bytes` was reached
    while (bytes < fin + 4) && bytes.value.unsafe_chr.in?(NL, NR)
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
      %decoded = DECODE_TABLE.unsafe_fetch({{byte}})
      %buffer = (%buffer << 6) + %decoded
      raise Base64::Error.new("Unexpected byte 0x#{{{byte}}.to_s(16)} at #{{{chunk_pos}} + {{i}}}") if %decoded == 255_u8
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
