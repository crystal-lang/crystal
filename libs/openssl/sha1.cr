require "./lib_crypto"

class OpenSSL::SHA1
  def self.hash(data : String)
    hash(data.cstr, C::SizeT.cast(data.bytesize))
  end

  def self.hash(data : UInt8*, length : C::SizeT)
    buffer :: UInt8[20]
    LibCrypto.sha1(data, length, buffer)
    buffer
  end
end
