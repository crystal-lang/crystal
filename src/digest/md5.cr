require "./base"
require "openssl"

# Implements the MD5 digest algorithm.
#
# Warning: MD5 is no longer a cryptographically secure hash, and should not be
# used in security-related components, like password hashing. For passwords, see
# `Crypto::Bcrypt::Password`. For a generic cryptographic hash, use SHA-256 via
# `OpenSSL::Digest.new("SHA256")`.
class Digest::MD5 < ::OpenSSL::Digest
  def initialize
    super("MD5")
  end
end
