require "./lib_crypto"

# Binds the OpenSSL MD5 hash functions.
#
# Warning: MD5 is no longer a cryptograpically safe hash, and should not be
# used for secure applications.
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
