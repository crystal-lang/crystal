require "lib_crypto"

class OpenSSL::HMAC
  def self.digest(algorithm, key : Slice(UInt8), data : Slice(UInt8))
    evp = LibCrypto.evp_sha1
    buffer = Slice(UInt8).new(128)
    LibCrypto.hmac(evp, key, key.length, data, data.length.to_u64, buffer, out buffer_len)
    buffer[0, buffer_len.to_i]
  end

  def self.digest(algorithm, key : String, data : String)
    digest(algorithm, Slice.new(key.cstr, key.bytesize), Slice.new(data.cstr, data.bytesize)).hexstring
  end
end
