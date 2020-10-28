require "./base"
require "openssl"

# Implements the SHA512 digest algorithm.
class Digest::SHA512 < ::OpenSSL::Digest
  def initialize
    super("SHA512")
  end
end
