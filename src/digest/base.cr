require "base64"

abstract class Digest::Base
  # Returns the hash of *data*. *data* must respond to `#to_slice`.
  def self.digest(data)
    digest do |ctx|
      ctx.update(data.to_slice)
    end
  end

  # Yields a context object with an `#update(data : String | Bytes)`
  # method available. Returns the resulting digest afterwards.
  #
  # ```
  # digest = Digest::MD5.digest do |ctx|
  #   ctx.update "f"
  #   ctx.update "oo"
  # end
  # digest.to_slice.hexstring # => "acbd18db4cc2f85cedef654fccc4a4d8"
  # ```
  def self.digest
    context = new
    yield context
    context.final
    context.result
  end

  # Returns the hexadecimal representation of the hash of *data*.
  #
  # ```
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
  # Digest::SHA1.base64digest("foo") # => "C+7Hteo/D9vJXQ3UfzxbwnXaijM="
  # ```
  def self.base64digest(data) : String
    base64digest &.update(data)
  end

  # Returns the base64-encoded hash of *data*.
  #
  # ```
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
