require "openssl"

class OpenSSL::Cipher::Writer < IO
  # Whether to close the enclosed `IO` when closing this writer.
  property? sync_close = false

  # Returns `true` if this writer is closed.
  getter? closed = false

  def initialize(@io : IO, cipher : String, key, iv, @sync_close : Bool = false)
    @cipher = OpenSSL::Cipher.new(cipher)
    @cipher.encrypt
    @cipher.key = key
    @cipher.iv = iv
  end

  # Creates a new writer to the given *filename*.
  def self.new(filename : String, cipher : String, key, iv)
    new(::File.new(filename, "w"), cipher: cipher, key: key, iv: iv, sync_close: true)
  end

  # Creates a new writer to the given *io*, yields it to the given block,
  # and closes it at the end.
  def self.open(io : IO, cipher : String, key, iv, sync_close = false)
    writer = new(io, cipher: cipher, key: key, iv: iv, sync_close: sync_close)
    yield writer ensure writer.close
  end

  # Creates a new writer to the given *filename*, yields it to the given block,
  # and closes it at the end.
  def self.open(filename : String, cipher : String, key, iv)
    writer = new(filename, cipher: cipher, key: key, iv: iv)
    yield writer ensure writer.close
  end

  # Always raises `IO::Error` because this is a write-only `IO`.
  def read(slice : Bytes)
    raise IO::Error.new("Can't read from OpenSSL::Cipher::Writer")
  end

  # See `IO#write`.
  def write(slice : Bytes)
    check_open

    return if slice.empty?

    @io.write(@cipher.update(slice))
  end

  # See `IO#flush`.
  def flush
    check_open

    @io.flush
  end

  def close
    return if @closed
    @closed = true

    @io.write(@cipher.final)
    @io.flush
    @io.close if @sync_close
  end
end
