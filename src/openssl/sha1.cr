require "./lib_crypto"

# Binds the OpenSSL SHA1 hash functions.
#
# Warning: SHA1 is no longer a cryptographically secure hash, and should not be
# used in security-related components, like password hashing. For passwords, see
# `Crypto::Bcrypt::Password`. For a generic cryptographic hash, use SHA-256 via
# `OpenSSL::Digest.new("SHA256")`.
class OpenSSL::SHA1
  def self.hash(data : String)
    hash(data.to_unsafe, LibC::SizeT.new(data.bytesize))
  end

  def self.hash(data : UInt8*, bytesize : LibC::SizeT)
    buffer = uninitialized UInt8[20]
    LibCrypto.sha1(data, bytesize, buffer)
    buffer
  end
end
