require "./lib_crypto"

class OpenSSL::MD5
  def self.hash(data : String)
    hash(data.cstr, LibC::SizeT.new(data.bytesize))
  end

  def self.hash(data : UInt8*, bytesize : LibC::SizeT)
    buffer :: UInt8[16]
    LibCrypto.md5(data, bytesize, buffer)
    buffer
  end
end
