require "./lib_crypto"

class OpenSSL::SHA512
  def self.hash(data : String) : UInt8[64]
    hash(data.to_unsafe, LibC::SizeT.new(data.bytesize))
  end

  def self.hash(data : UInt8*, bytesize : LibC::SizeT) : UInt8[64]
    buffer = uninitialized UInt8[64]
    LibCrypto.sha512(data, bytesize, buffer)
    buffer
  end
end
