require "./lib_crypto"

# Binds the OpenSSL MD5 hash functions.
#
# Warning: MD5 is no longer a cryptographically secure hash, and should not be
# used in security-related components, like password hashing. For passwords, see
# `Crypto::Bcrypt::Password`. For a generic cryptographic hash, use SHA-256 via
# `OpenSSL::Digest.new("SHA256")`.
class OpenSSL::MD5
  def self.hash(data : String) : UInt8[16]
    hash(data.to_unsafe, data.bytesize)
  end

  def self.hash(data : UInt8*, bytesize : Int) : UInt8[16]
    buffer = uninitialized UInt8[16]
    LibCrypto.md5(data, bytesize, buffer)
    buffer
  end
end
