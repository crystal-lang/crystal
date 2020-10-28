require "./base"
require "openssl"

# Implements the SHA1 digest algorithm.
#
# Warning: SHA1 is no longer a cryptographically secure hash, and should not be
# used in security-related components, like password hashing. For passwords, see
# `Crypto::Bcrypt::Password`. For a generic cryptographic hash, use SHA-256 via
# `OpenSSL::Digest.new("SHA256")`.
class Digest::SHA1 < ::OpenSSL::Digest
  def initialize
    super("SHA1")
  end
end
