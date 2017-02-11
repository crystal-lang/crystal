require "./header"

class Tar::Reader
  # Whether to close the enclosed `IO` when closing this reader.
  property? sync_close = false

  # Returns `true` if this reader is closed.
  getter? closed = false

  # Creates a new reader from the given *io*.
  def initialize(@io : IO, @sync_close = false)
    @end = false
  end

  # Creates a new reader from the given *filename*.
  def self.new(filename : String)
    new(::File.new(filename), sync_close: true)
  end

  # Creates a new reader from the given *io*, yields it to the given block,
  # and closes it at the end.
  def self.open(io : IO, sync_close = false)
    reader = new(io, sync_close: sync_close)
    yield reader ensure reader.close
  end

  # Creates a new reader from the given *filename*, yields it to the given block,
  # and closes it at the end.
  def self.open(filename : String)
    reader = new(filename)
    yield reader ensure reader.close
  end

  # Reads the next entry in the tar, or `nil` if there
  # are no more entries.
  #
  # After reading a next entry, previous entries can no
  # longer be read (their `IO` will be closed.)
  def next_entry : Entry?
    return if @end

    # Close previous entry if any, and skip padding up to a 512 byte alignment
    if last_entry = @last_entry
      last_entry.close
      padding = last_entry.padding
      @io.skip(padding) if padding > 0
    end

    # The tar file format consists of blocks of 512 bytes
    header_array = uninitialized UInt8[512]
    header = header_array.to_slice

    count = @io.read_fully_count(header)
    case count
    when 0
      # OK, a tar file can end without the trailing blocks of 512 bytes
      @end = true
      @last_entry = nil
      return
    when 512
      # OK, read it completely
    else
      raise(Tar::Error.new("expecting header, reached EOF"))
    end

    # The end of a tar file is signaled by two consecutive 512 blocks of zeroes.
    if header == ZERO_BLOCK
      @end = true
      @last_entry = nil

      @io.read_fully?(header) || raise(Tar::Error.new("expecting second zero block, reached EOF"))
      if header == ZERO_BLOCK
        return
      else
        raise Tar::Error.new("missing second zero block at end")
      end
    end

    @last_entry = Entry.new(header, @io)
  end

  # Closes this reader.
  def close
    return if @closed
    @closed = true
    @io.close if @sync_close
  end

  # A entry inside a `Tar::Reader`.
  #
  # Use the `io` method to read from it.
  class Entry < Tar::Header
    # Returns an `IO` to the entry's data.
    getter io : IO

    # :nodoc
    def initialize(header : Bytes, io : IO)
      super(header)
      @io = IO::Sized.new(io, size)
      @closed = false
    end

    protected def close
      return if @closed
      @closed = true
      @io.skip_to_end
      @io.close
    end
  end
end
