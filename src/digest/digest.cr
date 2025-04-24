require "base64"

# `Digest` is the base type of hashing algorithms like `Digest::MD5`,
# `Digest::SHA1`, `Digest::SHA256`, or `Digest::SHA512`.
#
# A `Digest` instance holds the state of an ongoing hash calculation.
# It can receive new data to include in the hash via `#update`, `#<<`, or `#file`.
# Once all data is included, use `#final` or `#hexfinal` to get the hash. This will mark the
# ongoing calculation as finished. A finished calculation can't receive new data.
#
# A `digest.dup.final` call may be used to get an intermediate hash value.
#
# Use `#reset` to reuse the `Digest` instance for a new calculation.
abstract class Digest
  class FinalizedError < Exception
  end

  # The `Digest::ClassMethods` module is used in the concrete subclass of `Digest`
  # that does not require arguments in its construction.
  #
  # The modules adds convenient class methods as `Digest::MD5.digest`, `Digest::MD5.hexdigest`.
  module ClassMethods
    # Returns the hash of *data*. *data* must respond to `#to_slice`.
    def digest(data) : Bytes
      digest do |ctx|
        ctx.update(data.to_slice)
      end
    end

    # Yields an instance of `self` which can receive calls to `#update(data : String | Bytes)`
    # and returns the finalized digest afterwards.
    #
    # ```
    # require "digest/md5"
    #
    # digest = Digest::MD5.digest do |ctx|
    #   ctx.update "f"
    #   ctx.update "oo"
    # end
    # digest.hexstring # => "acbd18db4cc2f85cedef654fccc4a4d8"
    # ```
    def digest(& : self ->) : Bytes
      context = new
      yield context
      context.final
    end

    # Returns the hexadecimal representation of the hash of *data*.
    #
    # ```
    # require "digest/md5"
    #
    # Digest::MD5.hexdigest("foo") # => "acbd18db4cc2f85cedef654fccc4a4d8"
    # ```
    def hexdigest(data) : String
      hexdigest &.update(data)
    end

    # Yields a context object with an `#update(data : String | Bytes)`
    # method available. Returns the resulting digest in hexadecimal representation
    # afterwards.
    #
    # ```
    # require "digest/md5"
    #
    # Digest::MD5.hexdigest("foo") # => "acbd18db4cc2f85cedef654fccc4a4d8"
    # Digest::MD5.hexdigest do |ctx|
    #   ctx.update "f"
    #   ctx.update "oo"
    # end
    # # => "acbd18db4cc2f85cedef654fccc4a4d8"
    # ```
    def hexdigest(& : self ->) : String
      hashsum = digest do |ctx|
        yield ctx
      end

      hashsum.to_slice.hexstring
    end

    # Returns the base64-encoded hash of *data*.
    #
    # ```
    # require "digest/sha1"
    #
    # Digest::SHA1.base64digest("foo") # => "C+7Hteo/D9vJXQ3UfzxbwnXaijM="
    # ```
    def base64digest(data) : String
      base64digest &.update(data)
    end

    # Yields a context object with an `#update(data : String | Bytes)`
    # method available. Returns the resulting digest in base64 representation
    # afterwards.
    #
    # ```
    # require "digest/sha1"
    #
    # Digest::SHA1.base64digest do |ctx|
    #   ctx.update "f"
    #   ctx.update "oo"
    # end
    # # => "C+7Hteo/D9vJXQ3UfzxbwnXaijM="
    # ```
    def base64digest(& : self -> _) : String
      hashsum = digest do |ctx|
        yield ctx
      end

      Base64.strict_encode(hashsum)
    end
  end

  @finished = false

  def update(data) : self
    update data.to_slice
  end

  def update(data : Bytes) : self
    check_finished
    update_impl data
    self
  end

  # Returns the final digest output.
  #
  # `final` or `hexfinal` can only be called once and raises `FinalizedError` on subsequent calls.
  #
  # NOTE: `.dup.final` call may be used to get an intermediate hash value.
  def final : Bytes
    dst = Bytes.new digest_size
    final dst
  end

  # Puts the final digest output into `dst`.
  #
  # Faster than the `Bytes` allocating version.
  # Use when hashing in loops.
  #
  # `final` or `hexfinal` can only be called once and raises `FinalizedError` on subsequent calls.
  #
  # NOTE: `.dup.final(dst)` call may be used to get an intermediate hash value.
  def final(dst : Bytes) : Bytes
    check_finished
    @finished = true
    final_impl dst
    dst
  end

  # Returns a hexadecimal-encoded digest in a new `String`.
  #
  # `final` or `hexfinal` can only be called once and raises `FinalizedError` on subsequent calls.
  #
  # NOTE: `.dup.hexfinal` call may be used to get an intermediate hash value.
  def hexfinal : String
    dsize = digest_size
    string_size = dsize * 2
    String.new(string_size) do |buffer|
      tmp = Slice.new(buffer + dsize, dsize)
      final tmp
      tmp.hexstring buffer
      {string_size, string_size}
    end
  end

  # Writes a hexadecimal-encoded digest to `dst`.
  #
  # Faster than the `String` allocating version.
  # Use when hashing in loops.
  #
  # `final` or `hexfinal` can only be called once and raises `FinalizedError` on subsequent calls.
  #
  # NOTE: `.dup.final` call may be used to get an intermediate hash value.
  def hexfinal(dst : Bytes) : Nil
    dsize = digest_size
    unless dst.bytesize == dsize * 2
      raise ArgumentError.new("Incorrect dst size: #{dst.bytesize}, expected: #{dsize * 2}")
    end

    tmp = dst[dsize, dsize]
    final tmp
    tmp.hexstring dst
  end

  # Writes a hexadecimal-encoded digest to `IO`.
  #
  # Faster than the `String` allocating version.
  #
  # `final` or `hexfinal` can only be called once and raises `FinalizedError` on subsequent calls.
  #
  # NOTE: `.dup.final` call may be used to get an intermediate hash value.
  #
  # This method is restricted to a maximum digest size of 64 bits. Implementations that allow
  # a larger digest size should override this method to use a larger buffer.
  def hexfinal(io : IO) : Nil
    if digest_size > 64
      raise "Digest#hexfinal(IO) can't handle digest_size over 64 bits"
    end
    sary = uninitialized StaticArray(UInt8, 128)
    tmp = sary.to_slice[0, digest_size * 2]
    hexfinal tmp
    io << tmp
  end

  # Resets the state of this object.  Use to get another hash value without creating a new object.
  def reset : self
    reset_impl
    @finished = false
    self
  end

  # Reads the file's content and updates the digest with it.
  def file(file_name : Path | String) : self
    File.open(file_name) do |io|
      # `#update` works with big buffers so there's no need for additional read buffering in the file
      io.read_buffering = false
      self << io
    end
  end

  # Reads the io's data and updates the digest with it.
  def update(io : IO) : self
    buffer = uninitialized UInt8[IO::DEFAULT_BUFFER_SIZE]
    while (read_bytes = io.read(buffer.to_slice)) > 0
      self << buffer.to_slice[0, read_bytes]
    end
    self
  end

  # :ditto:
  def <<(data) : self
    update(data)
  end

  private def check_finished : Nil
    raise FinalizedError.new("finish already called") if @finished
  end

  # Hashes data incrementally.
  abstract def update_impl(data : Bytes) : Nil
  # Stores the output digest of #digest_size bytes in dst.
  abstract def final_impl(dst : Bytes) : Nil
  # Resets the object to it's initial state.
  abstract def reset_impl : Nil
  # Returns the digest output size in bytes.
  abstract def digest_size : Int32
end
