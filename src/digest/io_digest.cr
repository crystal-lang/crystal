require "./digest"
require "openssl/digest"

# Wraps an `IO` by calculating a specified `Digest` on read or write operations.
#
# ### Example
#
# ```
# require "digest"
#
# underlying_io = IO::Memory.new("foo")
# io = IO::Digest.new(underlying_io, Digest::SHA256.new)
# buffer = Bytes.new(256)
# io.read(buffer)
# io.final.hexstring # => "2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae"
# ```
class IO::Digest < IO
  getter io : IO
  getter digest_algorithm : ::Digest
  getter mode : DigestMode

  delegate close, closed?, flush, peek, tty?, rewind, to: @io
  delegate final, to: @digest_algorithm

  enum DigestMode
    Read
    Write
  end

  def initialize(@io : IO, @digest_algorithm : ::Digest, @mode = DigestMode::Read)
  end

  def read(slice : Bytes) : Int32
    read_bytes = io.read(slice).to_i32
    if @mode.read?
      digest_algorithm.update(slice[0, read_bytes])
    end
    read_bytes
  end

  def write(slice : Bytes) : Nil
    return if slice.empty?

    if @mode.write?
      digest_algorithm.update(slice)
    end
    io.write(slice)
  end
end
