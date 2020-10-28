require "./base"
require "openssl"

# Implements the SHA256 digest algorithm.
class Digest::SHA256 < ::OpenSSL::Digest
  def initialize
    super("SHA256")
  end
end
