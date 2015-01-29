require "./lib_crypto"

class OpenSSL::MD5
  def self.hash(data : String)
    hash(data.cstr, LibC::SizeT.cast(data.bytesize))
  end

  def self.hash(data : UInt8*, length : LibC::SizeT)
    buffer :: UInt8[16]
    LibCrypto.md5(data, length, buffer)
    buffer
  end
end
