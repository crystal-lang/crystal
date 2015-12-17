require "./lib_crypto"

class OpenSSL::SHA1
  def self.hash(data : String)
    hash(data.to_unsafe, LibC::SizeT.new(data.bytesize))
  end

  def self.hash(data : UInt8*, bytesize : LibC::SizeT)
    buffer :: UInt8[20]
    LibCrypto.sha1(data, bytesize, buffer)
    buffer
  end
end
