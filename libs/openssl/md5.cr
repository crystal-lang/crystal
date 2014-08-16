require "lib_crypto"

class OpenSSL::MD5
  def self.hash(data : String)
    hash(data.cstr, data.bytesize.to_sizet)
  end

  def self.hash(data : UInt8*, length : C::SizeT)
    buffer :: UInt8[16]
    LibCrypto.md5(data, length, buffer)
    buffer
  end
end
