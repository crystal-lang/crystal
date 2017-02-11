require "./header"

class Tar::Writer
  # Whether to close the enclosed `IO` when closing this writer.
  property? sync_close = false

  # Returns `true` if this writer is closed.
  getter? closed = false

  # Creates a new writer to the given *io*.
  def initialize(@io : IO, @sync_close = false)
    @counter_writer = CounterWriter.new(@io)
  end

  # Creates a new writer to the given *filename*.
  def self.new(filename : String)
    new(::File.new(filename, "w"), sync_close: true)
  end

  # Creates a new writer to the given *io*, yields it to the given block,
  # and closes it at the end.
  def self.open(io : IO, sync_close = false)
    writer = new(io, sync_close: sync_close)
    yield writer ensure writer.close
  end

  # Creates a new writer to the given *filename*, yields it to the given block,
  # and closes it at the end.
  def self.open(filename : String)
    writer = new(filename)
    yield writer ensure writer.close
  end

  # Adds an entry into the tar.
  #
  # To add an entry, create a `Tar::Header`, set its attributes
  # and pass it to this method. An `IO` is yielded to which
  # the entry's data must be written.
  #
  # The header must specify the total amount of bytes (size) to
  # write, and exactly that amount of bytes must be written,
  # otherwise `Tar::Error` will be raised.
  def add(header : Tar::Header)
    size = header.size
    padding = header.padding

    header.to_io(@io)

    @counter_writer.reset
    yield @counter_writer

    if @counter_writer.count != size
      raise Tar::Error.new("expected #{size} bytes to be written, but only #{@counter_writer.count} were written")
    end

    if padding != 0
      @io.write(ZERO_BLOCK[0, padding])
    end
  end

  # Adds an entry that will have *data* as its contents.
  def add(header : Tar::Header, data : String)
    add(header, data.to_slice)
  end

  # Adds an entry that will have *data* as its contents.
  def add(header : Tar::Header, data : Bytes)
    header.size = data.size
    add(header) do |io|
      io.write(data)
    end
  end

  # Adds an entry that will have its data copied from the given *data*.
  # If the given *data* is a `::File`, it is automatically closed
  # after data is copied from it.
  #
  # The header must specify the total amount of bytes (size) to
  # write, and exactly that amount of bytes must be written,
  # otherwise `Tar::Error` will be raised.
  def add(header : Tar::Header, data : IO)
    add(header) do |io|
      IO.copy(data, io)
      data.close if data.is_a?(::File)
    end
  end

  # Adds an entry with the given *name*, *mode* and *data*.
  def add(name : String, mode : Int32, data : String)
    add(name, mode, data.to_slice)
  end

  # Adds an entry with the given *name*, *mode* and *data*.
  def add(name : String, mode : Int32, data : Bytes)
    header = Tar::Header.new(name, Header::Type::REG, mode)
    header.size = data.size
    add(header) do |io|
      io.write(data)
    end
  end

  # Adds a directory with the given *name* and *mode*.
  def add_dir(name : String, mode : Int32)
    name += '/' unless name.ends_with?('/')

    header = Tar::Header.new(name, Header::Type::DIR, mode)
    add(header) { }
  end

  # Closes this tar writer.
  def close
    return if @closed
    @closed = true

    # Signal the end, which is two blocks of 512 zero bytes
    @io.write(ZERO_BLOCK)
    @io.write(ZERO_BLOCK)

    @io.close if @sync_close
  end
end
