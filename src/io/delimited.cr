# An `IO` that wraps another `IO`, and only reads up to the beginning of a
# specified delimiter.
#
# This is useful for exposing part of an underlying stream to a client.
#
# ```
# io = IO::Memory.new "abc||123"
# delimited = IO::Delimited.new(io, read_delimiter: "||")
#
# delimited.gets_to_end # => "abc"
# delimited.gets_to_end # => ""
# io.gets_to_end        # => "123"
# ```
class IO::Delimited < IO
  # If `#sync_close?` is `true`, closing this `IO` will close the underlying `IO`.
  property? sync_close

  getter read_delimiter
  getter? closed : Bool

  @delimiter_buffer : Bytes
  @active_delimiter_buffer : Bytes

  # Creates a new `IO::Delimited` which wraps *io*, and can read until the
  # byte sequence *read_delimiter* (interpreted as UTF-8) is found. If
  # *sync_close* is set, calling `#close` calls `#close` on the underlying
  # `IO`.
  def self.new(io : IO, read_delimiter : String, sync_close : Bool = false)
    new(io, read_delimiter.to_slice, sync_close)
  end

  # Creates a new `IO::Delimited` which wraps *io*, and can read until the
  # byte sequence *read_delimiter* is found. If *sync_close* is set, calling
  # `#close` calls `#close` on the underlying `IO`.
  def initialize(@io : IO, @read_delimiter : Bytes, @sync_close : Bool = false)
    @closed = false
    @finished = false

    # The buffer where we do all our work.
    @delimiter_buffer = Bytes.new(@read_delimiter.size)
    # Slice inside delimiter buffer where bytes waiting to be read are stored.
    @active_delimiter_buffer = Bytes.empty
  end

  def read(slice : Bytes)
    check_open
    return 0 if @finished

    first_byte = @read_delimiter[0]
    read_bytes = 0

    while read_bytes < slice.size
      # Select the next byte as the head of the active delimiter buffer,
      # or the next byte from the io if the buffer is not in use.
      if @active_delimiter_buffer.size > 0
        byte = @active_delimiter_buffer[0]
        @active_delimiter_buffer += 1
      else
        byte = @io.read_byte
      end

      break if byte.nil?

      # We know we don't need to check if the delimiter matches when the buffer
      # has been resized, because this signals we are coming to the end of the IO.
      if byte == first_byte && @delimiter_buffer.size == @read_delimiter.size
        buffer = @delimiter_buffer
        buffer[0] = byte
        read_start = 1

        # If we have an active delimiter buffer copy it in after the current
        # character, and update where we should start our read operation.
        if @active_delimiter_buffer.size > 0
          (buffer + 1).move_from(@active_delimiter_buffer)
          read_start += @active_delimiter_buffer.size
        end

        read_buffer = buffer + read_start
        bytes = 0
        while read_buffer.size > 0
          partial_bytes = @io.read(read_buffer)
          break if partial_bytes == 0

          read_buffer += partial_bytes
          bytes += partial_bytes
        end

        # If read didn't read as many bytes as we asked it to, resize the buffer
        # to remove garbage bytes.
        if bytes != buffer.size - read_start
          buffer = buffer[0, read_start + bytes]
        end

        if buffer == @read_delimiter
          @finished = true
          return read_bytes
        end

        @delimiter_buffer = buffer
        @active_delimiter_buffer = buffer + 1
      end

      slice[read_bytes] = byte
      read_bytes += 1
    end

    read_bytes
  end

  def write(slice : Bytes)
    raise IO::Error.new "Can't write to IO::Delimited"
  end

  def close
    return if @closed
    @closed = true

    @io.close if @sync_close
  end
end
