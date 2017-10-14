# An `IO` that wraps another `IO`, setting a limit for the number of bytes that can be read.
#
# ```
# io = IO::Memory.new "abcde"
# sized = IO::Sized.new(io, read_size: 3)
#
# sized.gets_to_end # => "abc"
# sized.gets_to_end # => ""
# io.gets_to_end    # => "de"
# ```
class IO::Sized < IO
  # If `#sync_close?` is `true`, closing this `IO` will close the underlying `IO`.
  property? sync_close : Bool

  # The number of remaining bytes to be read.
  getter read_remaining : UInt64
  getter? closed : Bool

  # Creates a new `IO::Sized` which wraps *io*, and can read a maximum of
  # *read_size* bytes. If *sync_close* is set, calling `#close` calls
  # `#close` on the underlying `IO`.
  def initialize(@io : IO, read_size : Int, @sync_close = false)
    raise ArgumentError.new "Negative read_size" if read_size < 0
    @closed = false
    @read_remaining = read_size.to_u64
  end

  def read(slice : Bytes)
    check_open

    count = {slice.size.to_u64, @read_remaining}.min
    bytes_read = @io.read slice[0, count]
    @read_remaining -= bytes_read
    bytes_read
  end

  def read_byte
    check_open

    if @read_remaining > 0
      byte = @io.read_byte
      @read_remaining -= 1 if byte
      byte
    else
      nil
    end
  end

  def peek
    check_open

    return Bytes.empty if @read_remaining == 0 # EOF

    peek = @io.peek
    return nil unless peek

    if @read_remaining < peek.size
      peek = peek[0, @read_remaining]
    end

    peek
  end

  def skip(bytes_count) : Nil
    check_open

    if bytes_count <= @read_remaining
      @io.skip(bytes_count)
      @read_remaining -= bytes_count
    else
      raise IO::EOFError.new
    end
  end

  def write(slice : Bytes)
    raise IO::Error.new "Can't write to IO::Sized"
  end

  def close
    return if @closed
    @closed = true

    @io.close if @sync_close
  end
end
