require "./digest_base"

# Wraps an IO by calculating a specified digest on read and/or write operations.
#
# ### Example
#
# ```
# require "openssl"
#
# underlying_io = IO::Memory.new("foo")
# io = OpenSSL::DigestIO.new(underlying_io, "SHA256")
# buffer = Bytes.new(256)
# io.read(buffer)
# io.digest # => 2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae
# ```
#
module OpenSSL
  class DigestIO
    include IO

    getter io : IO
    getter digest_algorithm : OpenSSL::Digest
    getter digest_on_read : Bool
    getter digest_on_write : Bool

    delegate close, closed?, flush, peek, tty?, rewind, to: @io
    delegate digest, to: @digest_algorithm
    delegate digest, hexdigest, base64digest, to: @digest_algorithm

    def initialize(@io : IO, @digest_algorithm : OpenSSL::Digest, *, @digest_on_read = true, @digest_on_write = true)
    end

    def initialize(@io : IO, algorithm : String, *, @digest_on_read = true, @digest_on_write = true)
      @digest_algorithm = OpenSSL::Digest.new(algorithm)
    end

    def read(slice : Bytes)
      read_bytes = io.read(slice)
      if @digest_on_read
        digest_algorithm.update(slice[0, read_bytes])
      end
      read_bytes
    end

    def write(slice : Bytes)
      if @digest_on_write
        digest_algorithm.update(slice)
      end
      io.write(slice)
    end
  end
end
