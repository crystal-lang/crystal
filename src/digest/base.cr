require "base64"

module Digest
  class FinalizedError < Exception
  end
end

abstract class Digest::Base
  macro inherited
    # Returns the hash of *data*. *data* must respond to `#to_slice`.
    def self.digest(data)
      digest do |ctx|
        ctx.update(data.to_slice)
      end
    end

    # Yields an instance of `self` which can receive calls to `#update(data : String | Bytes)` and returns the finalized digest.
    # method available. Returns the resulting digest afterwards.
    #
    # ```
    # require "digest/md5"
    #
    # digest = Digest::MD5.digest do |ctx|
    #   ctx.update "f"
    #   ctx.update "oo"
    # end
    # digest.to_slice.hexstring # => "acbd18db4cc2f85cedef654fccc4a4d8"
    # ```
    def self.digest : Bytes
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
    def self.hexdigest(data) : String
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
    def self.hexdigest : String
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
    def self.base64digest(data) : String
      base64digest &.update(data)
    end

    # Returns the base64-encoded hash of *data*.
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
    def self.base64digest : String
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

  # Returns the final digest output.
  #
  # This method can only be called once and raises `FinalizedError` on subsequent calls.
  #
  # NOTE: `.dup.final` call may be used to get an intermediate hash value.
  def final : Bytes
    dst = Bytes.new digest_size
    final dst
  end

  # Dups and finishes the digest.
  @[Deprecated("Use `final` instead.")]
  def digest : Bytes
    dup.final
  end

  # Returns a hexadecimal-encoded digest.
  @[Deprecated("Use `final.hexstring` instead.")]
  def hexdigest : String
    digest.hexstring
  end

  protected def check_finished : Nil
    raise FinalizedError.new("finish already called") if @finished
  end

  protected def set_finished : Nil
    check_finished
    @finished = true
  end

  # Override.
  def reset : self
    @finished = false
    self
  end

  # When creating a new digest class call #check_finished before mutating.
  abstract def update(data : Bytes) : self
  # When creating a new digest class call #set_finished before mutating.
  abstract def final(dst : Bytes) : Bytes
  abstract def digest_size : Int32
end
