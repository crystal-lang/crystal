require "io"

# `PrefixSuffixBuffer` is an `IO` that retains the first bytes in the prefix
# buffer and the last bytes in the suffix buffer.
#
# When writing more bytes than fit in the buffers, only the start and end bytes
# are preserved.
# `#to_s` renders the buffer contents with a message indicating how many
# bytes were omitted.
@[Experimental]
class IO::PrefixSuffixBuffer < IO
  # Creates an instance with prefix and suffix buffers of the given size.
  #
  # The maximum size that this instance can consume without omitting data is
  # `size * 2`.
  def self.new(size : Int32 = IO::DEFAULT_BUFFER_SIZE) : self
    buffer_size = size * 2
    String.check_capacity_in_bounds(buffer_size)

    buffer = Bytes.new(buffer_size)
    new(buffer[0, size], buffer + size)
  end

  # Creates an instance using the given buffers.
  #
  # The maximum size that this instance can consume without omitting data is the
  # sum of the buffer sizes.
  def initialize(@prefix : Bytes, @suffix : Bytes)
    @pos = 0
  end

  def read(slice : Bytes) : NoReturn
    raise "Can't read from IO::PrefixSuffixBuffer"
  end

  def write(slice : Bytes) : Nil
    check_open

    return if slice.empty?

    total = slice.size

    # Fill the prefix linearly.
    slice += fill(@prefix, slice, @pos)

    # The suffix works as a ring buffer.
    suffix = @suffix
    if slice.size >= suffix.bytesize
      ring_pos = slice.size
      slice = slice[(-suffix.bytesize)..]
    else
      ring_pos = -suffix.bytesize
    end

    if suffix.bytesize > 0
      # The first chunk goes to the ring buffer after `ring_pos`
      slice += fill(suffix, slice, ((@pos - @prefix.bytesize).clamp(0..) + ring_pos) % suffix.bytesize)
    end

    # The second chunk goes to the ring buffer before `ring_pos`
    fill(suffix, slice, 0)

    # We add the total size, not the number of actually written bytes because
    # we may skip writing some of the middle bytes if `total` exceeds the buffer
    # capacity.
    @pos += total
  end

  private def fill(buffer, slice, pos)
    max_size = buffer.bytesize - pos

    return 0 if max_size <= 0
    count = slice.size.clamp(..max_size)
    slice[0, count].copy_to(buffer.to_unsafe + pos, count)
    count
  end

  def capacity
    @prefix.bytesize + @suffix.bytesize
  end

  def total_size
    @pos
  end

  def to_s : String
    capacity = total_size.clamp(0, @prefix.bytesize + @suffix.bytesize + 50)
    String.build(capacity) do |io|
      to_s(io)
    end
  end

  # Appends the buffer to the given `IO`.
  #
  # When the total size of the consumed data exceeds the buffer size, the middle
  # part is omitted and replaced by a message that indicates the number of
  # skipped bytes.
  def to_s(io : IO) : Nil
    prefix = @prefix
    suffix = @suffix
    total = self.total_size

    buffer_size = prefix.bytesize + suffix.bytesize

    io.write prefix[0, total.clamp(..prefix.bytesize)]

    ring_pos = total - prefix.bytesize

    if ring_pos > suffix.bytesize
      io << "\n...omitted " << (total - buffer_size) << " bytes...\n"

      if suffix.bytesize > 0
        ring_pos %= suffix.bytesize
        io.write suffix + ring_pos
      end
    end

    if suffix.bytesize > 0
      io.write suffix[0, ring_pos.clamp(0..)]
    end
  end
end
