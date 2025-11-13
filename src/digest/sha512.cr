require "./digest"
require "openssl/digest"

# Implements the SHA512 digest algorithm.
#
# NOTE: To use `SHA512`, you must explicitly import it with `require "digest/sha512"`
class Digest::SHA512 < ::OpenSSL::Digest
  extend ClassMethods

  def initialize
    super("SHA512")
  end

  protected def initialize(ctx : LibCrypto::EVP_MD_CTX)
    super("SHA512", ctx)
  end

  def dup
    self.class.new(dup_ctx)
  end
end
