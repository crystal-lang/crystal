require "./digest"
require "openssl/digest"

# Implements the SHA256 digest algorithm.
#
# NOTE: To use `SHA256`, you must explicitly import it with `require "digest/sha256"`
class Digest::SHA256 < ::OpenSSL::Digest
  extend ClassMethods

  def initialize
    super("SHA256")
  end

  protected def initialize(ctx : LibCrypto::EVP_MD_CTX)
    super("SHA256", ctx)
  end

  def dup
    self.class.new(dup_ctx)
  end
end
