require "openssl"

class OpenSSL::Cipher::Reader < IO
  include IO::Buffered

  # Whether to close the enclosed `IO` when closing this reader.
  property? sync_close = false

  # Returns `true` if this reader is closed.
  getter? closed = false

  def initialize(@io : IO, cipher : String, key, iv, @sync_close : Bool = false)
    @cipher = OpenSSL::Cipher.new(cipher)
    @cipher.key = key
    @cipher.iv = iv
    @cipher.decrypt
  end

  def initialize(@io : IO, @cipher, @sync_close : Bool = false)
  end

  # Creates a new reader from the given *io*, yields it to the given block,
  # and closes it at the end.
  def self.open(io : IO, cipher : String, key, iv, sync_close = false)
    reader = new(io, cipher: cipher, key: key, iv: iv, sync_close: sync_close)
    yield reader ensure reader.close
  end

  # See `IO#read`.
  def unbuffered_read(slice : Bytes)
    check_open

    return 0 if slice.empty?

    read_bytes = @io.read(slice)

    data = @cipher.update(slice)
    slice.move_from(data[0, read_bytes])

    read_bytes
  end

  # Always raises `IO::Error` because this is a read-only `IO`.
  def unbuffered_write(slice : Bytes)
    raise IO::Error.new "Can't write to OpenSSL::Cipher::Reader"
  end

  def unbuffered_flush
    raise IO::Error.new "Can't flush OpenSSL::Cipher::Reader"
  end

  def unbuffered_close
    return if @closed
    @closed = true

    # @io.write(@cipher.final)
    @io.close if @sync_close
  end

  def unbuffered_rewind
    check_open

    @io.rewind
    @cipher.reset

    initialize(@io, @cipher, @sync_close)
  end
end
