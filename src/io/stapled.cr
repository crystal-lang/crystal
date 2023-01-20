# This class staples together two unidirectional `IO`s to form a single,
# bidirectional `IO`.
#
# Example (loopback):
# ```
# io = IO::Stapled.new(*IO.pipe)
# io.puts "linus"
# io.gets # => "linus"
# ```
#
# Most methods simply delegate to the underlying `IO`s.
class IO::Stapled < IO
  # If `#sync_close?` is `true`, closing this `IO` will close the underlying `IO`s.
  property? sync_close : Bool

  # Returns `true` if this `IO` is closed.
  #
  # Underlying `IO`s might have a different status.
  getter? closed : Bool = false

  # Creates a new `IO::Stapled` which reads from *reader* and writes to *writer*.
  def initialize(@reader : IO, @writer : IO, @sync_close : Bool = false)
  end

  # Reads a single byte from `reader`.
  def read_byte : UInt8?
    check_open

    @reader.read_byte
  end

  # Reads a slice from `reader`.
  def read(slice : Bytes) : Int32
    check_open

    @reader.read(slice).to_i32
  end

  # Gets a string from `reader`.
  def gets(delimiter : Char, limit : Int, chomp = false) : String?
    check_open

    @reader.gets(delimiter, limit, chomp)
  end

  # Peeks into `reader`.
  def peek : Bytes?
    check_open

    @reader.peek
  end

  # Skips `reader`.
  def skip(bytes_count : Int) : Nil
    check_open

    @reader.skip(bytes_count)
  end

  # Skips `reader`.
  def skip_to_end : Nil
    check_open

    @reader.skip_to_end
  end

  # Writes a byte to `writer`.
  def write_byte(byte : UInt8) : Nil
    check_open

    @writer.write_byte(byte)
  end

  # Writes a slice to `writer`.
  def write(slice : Bytes) : Nil
    check_open

    return if slice.empty?

    @writer.write(slice)
  end

  # Flushes `writer`.
  def flush : self
    check_open

    @writer.flush

    self
  end

  # Closes this `IO`.
  #
  # If `sync_close?` is `true`, it will also close the underlying `IO`s.
  def close : Nil
    return if @closed
    @closed = true

    if @sync_close
      @reader.close
      @writer.close
    end
  end

  # Creates a pair of bidirectional pipe endpoints connected with each other
  # and passes them to the given block.
  #
  # Both endpoints and the underlying `IO`s are closed after the block
  # (even if `sync_close?` is `false`).
  def self.pipe(read_blocking : Bool = false, write_blocking : Bool = false, &)
    IO.pipe(read_blocking, write_blocking) do |a_read, a_write|
      IO.pipe(read_blocking, write_blocking) do |b_read, b_write|
        a, b = new(a_read, b_write, true), new(b_read, a_write, true)
        begin
          yield a, b
        ensure
          a.close
          b.close
        end
      end
    end
  end

  # Creates a pair of bidirectional pipe endpoints connected with each other
  # and returns them in a `Tuple`.
  def self.pipe(read_blocking : Bool = false, write_blocking : Bool = false) : {self, self}
    a_read, a_write = IO.pipe(read_blocking, write_blocking)
    b_read, b_write = IO.pipe(read_blocking, write_blocking)
    return new(a_read, b_write, true), new(b_read, a_write, true)
  end
end
