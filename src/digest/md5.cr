require "./digest"
require "openssl"

# Implements the MD5 digest algorithm.
#
# Warning: MD5 is no longer a cryptographically secure hash, and should not be
# used in security-related components, like password hashing. For passwords, see
# `Crypto::Bcrypt::Password`. For a generic cryptographic hash, use SHA-256 via
# `Digest::SHA256`.
class Digest::MD5 < ::OpenSSL::Digest
  extend ClassMethods

  def initialize
    super("MD5")
  end

  protected def initialize(ctx : LibCrypto::EVP_MD_CTX)
    super("MD5", ctx)
  end

  def dup
    self.class.new(dup_ctx)
  end
end
