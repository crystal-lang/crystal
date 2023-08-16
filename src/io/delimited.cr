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

  def read(slice : Bytes) : Int32
    check_open

    if @finished
      # We might still have stuff to read from @active_delimiter_buffer
      return read_from_active_delimited_buffer(slice)
    end

    read_internal(slice)
  end

  private def read_internal(slice : Bytes) : Int32
    if peek = @io.peek
      read_with_peek(slice, peek)
    else
      read_without_peek(slice)
    end
  end

  private def read_with_peek(slice : Bytes, peek : Bytes) : Int32
    # If there's nothing else to peek, we reached EOF
    if peek.empty?
      @finished = true

      if @active_delimiter_buffer.empty?
        return 0
      else
        # If we have something in the active delimiter buffer,
        # but we don't have any more data to read, that wasn't
        # the delimiter so we must include it in the slice.
        return read_from_active_delimited_buffer(slice)
      end
    end

    first_byte = @read_delimiter[0]

    # If we have something in the active delimiter buffer
    unless @active_delimiter_buffer.empty?
      # This is the rest of the delimiter we have to match
      delimiter_remaining = @read_delimiter[@active_delimiter_buffer.size..]

      # This is how much we can actually match of that (peek might not have enough data!)
      min_size = Math.min(delimiter_remaining.size, peek.size)

      # See if what remains to match in the delimiter matches whatever
      # we have in peek, limited to what's available
      if delimiter_remaining[0, min_size] == peek[0, min_size]
        # If peek has enough data to match the entire rest of the delimiter...
        if peek.size >= delimiter_remaining.size
          # We found the delimiter!
          @io.skip(min_size)
          @active_delimiter_buffer = Bytes.empty
          @finished = true
          return 0
        else
          # Copy the remaining of peek to the active delimiter buffer for now
          (@delimiter_buffer + @active_delimiter_buffer.size).copy_from(peek)
          @active_delimiter_buffer = @delimiter_buffer[0, @active_delimiter_buffer.size + peek.size]

          # Skip whatever we had in peek, and try reading more
          @io.skip(peek.size)
          return read_internal(slice)
        end
      else
        # No match.
        # We first need to check if the delimiter could actually start in this active buffer.
        next_index = @active_delimiter_buffer.index(first_byte, 1)

        # We read up to that new match, if any, or the entire buffer
        read_bytes = next_index || @active_delimiter_buffer.size

        slice.copy_from(@active_delimiter_buffer[0, read_bytes])
        slice += read_bytes
        @active_delimiter_buffer += read_bytes
        return read_bytes + read_internal(slice)
      end
    end

    index =
      if slice.size == 1
        # For a size of 1, this is much faster
        first_byte == peek[0] ? 0 : nil
      elsif slice.size < peek.size
        peek[0, slice.size].index(first_byte)
      else
        peek.index(first_byte)
      end

    # If we can't find the delimiter's first byte we can just read from peek
    unless index
      # If we have more in peek than what we need to read, read all of that
      if peek.size >= slice.size
        if slice.size == 1
          # For a size of 1, this is much faster
          slice[0] = peek[0]
        else
          slice.copy_from(peek[0, slice.size])
        end
        @io.skip(slice.size)
        return slice.size
      else
        # Otherwise, read from peek for now
        slice.copy_from(peek)
        @io.skip(peek.size)
        return peek.size
      end
    end

    # If the delimiter is just a single byte, we can stop right here
    if @delimiter_buffer.size == 1
      slice.copy_from(peek[0, index])
      @io.skip(index + 1)
      @finished = true
      return index
    end

    # If the delimiter fits the rest of the peek buffer,
    # we can check it right now.
    if index + @delimiter_buffer.size <= peek.size
      # If we found the delimiter, we are done
      if peek[index, @delimiter_buffer.size] == @read_delimiter
        slice.copy_from(peek[0, index])
        @io.skip(index + @delimiter_buffer.size)
        @finished = true
        return index
      else
        # Otherwise, we can read up to past that byte for now
        slice.copy_from(peek[0, index + 1])
        @io.skip(index + 1)
        slice += index + 1
        return index + 1
      end
    end

    # If the part past in the peek buffer past the matching index
    # doesn't match the read delimiter's portion, we can move on
    rest = peek[index..]
    unless rest == @read_delimiter[0, rest.size]
      # We can read up to past that byte for now
      safe_to_read = peek[0, index + 1]
      slice.copy_from(safe_to_read)
      @io.skip(safe_to_read.size)
      slice += safe_to_read.size
      return safe_to_read.size
    end

    # Copy up to index into slice
    slice.copy_from(peek[0, index])
    slice += index

    # Copy the rest of the peek buffer into delimted buffer
    @delimiter_buffer.copy_from(rest)
    @active_delimiter_buffer = @delimiter_buffer[0, rest.size]

    @io.skip(peek.size)

    index + read_internal(slice)
  end

  private def read_from_active_delimited_buffer(slice : Bytes) : Int32
    if @active_delimiter_buffer.empty?
      return 0
    end

    available = Math.min(@active_delimiter_buffer.size, slice.size)
    slice.copy_from(@active_delimiter_buffer[0, available])
    @active_delimiter_buffer += available
    available
  end

  private def read_without_peek(slice : Bytes) : Int32
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
          @active_delimiter_buffer = Bytes.empty
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

  def write(slice : Bytes) : Nil
    raise IO::Error.new "Can't write to IO::Delimited"
  end

  def peek : Bytes?
    if @finished
      # It's fine to return this internal buffer because peek
      # clients aren't supposed to write to that buffer.
      return @active_delimiter_buffer
    end

    peek = @io.peek
    return nil unless peek
    return peek if peek.empty?

    # See if we can find the first byte
    first_byte = @read_delimiter[0]

    offset = 0
    loop do
      index = peek.index(first_byte, offset: offset)

      # If we can't find it, the entire underlying peek buffer is visible
      unless index
        return peek
      end

      # If the delimiter is just one byte, we found it!
      if @read_delimiter.size == 1
        return peek[0, index]
      end

      # If the delimiter fits the rest of the peek buffer,
      # we can check it right now.
      if index + @delimiter_buffer.size <= peek.size
        # If we found the delimiter, we are done
        if peek[index, @delimiter_buffer.size] == @read_delimiter
          return peek[0, index]
        else
          offset = index + 1
          next
        end
      else
        # Otherwise we can't know without reading further,
        # return what we have so far
        if index == 0
          # Check if whatever remains in peek actually matches the delimiter.
          min_size = Math.min(@read_delimiter.size, peek.size)
          if @read_delimiter[0, min_size] == peek[0, min_size]
            # The entire peek buffer partially matches the delimiter,
            # but we don't know what will happen next. We can't peek.
            return nil
          else
            # It didn't fully match, so we can at least return
            # the part up to the next match
            next_index = peek.index(first_byte, 1)
            return peek[0, next_index || peek.size]
          end
        else
          return peek[0, index]
        end
      end
    end
  end

  def close : Nil
    return if @closed
    @closed = true

    @io.close if @sync_close
  end
end
