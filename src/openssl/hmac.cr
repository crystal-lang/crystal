require "./lib_crypto"
require "openssl/algorithm"

# Allows computing Hash-based Message Authentication Code (HMAC).
#
# It is a type of message authentication code (MAC)
# involving a hash function in combination with a key.
#
# HMAC can be used to verify the integrity of a message as well as the authenticity.
#
# See also [RFC2104](https://tools.ietf.org/html/rfc2104.html).
class OpenSSL::HMAC
  # Returns the HMAC digest of *data* using the secret *key*.
  #
  # It may contain non-ASCII bytes, including NUL bytes.
  #
  # *algorithm* specifies which `OpenSSL::Algorithm` is to be used.
  def self.digest(algorithm : OpenSSL::Algorithm, key, data) : Bytes
    evp = algorithm.to_evp
    key_slice = key.to_slice
    data_slice = data.to_slice
    buffer = Bytes.new(128)
    LibCrypto.hmac(evp, key_slice, key_slice.size, data_slice, data_slice.size, buffer, out buffer_len)
    buffer[0, buffer_len.to_i]
  end

  # Returns the HMAC digest of *data* using the secret *key*,
  # formatted as a hexadecimal string. This is necessary to safely transfer
  # the digest where binary messages are not allowed.
  #
  # See also `#digest`.
  def self.hexdigest(algorithm : OpenSSL::Algorithm, key, data) : String
    digest(algorithm, key, data).hexstring
  end
end
