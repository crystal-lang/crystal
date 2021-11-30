require "./digest"
require "openssl"

# Implements the SHA256 digest algorithm.
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
