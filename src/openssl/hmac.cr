require "./lib_crypto"

class OpenSSL::HMAC
  def self.digest(algorithm : Symbol, key, data) : Slice(UInt8)
    evp = case algorithm
          when :dss       then LibCrypto.evp_dss
          when :dss1      then LibCrypto.evp_dss1
          when :md4       then LibCrypto.evp_md4
          when :md5       then LibCrypto.evp_md5
          when :ripemd160 then LibCrypto.evp_ripemd160
          when :sha1      then LibCrypto.evp_sha1
          when :sha224    then LibCrypto.evp_sha224
          when :sha256    then LibCrypto.evp_sha256
          when :sha384    then LibCrypto.evp_sha384
          when :sha512    then LibCrypto.evp_sha512
          else                 raise "Unsupported digest algorithm: #{algorithm}"
          end
    key_slice = key.to_slice
    data_slice = data.to_slice
    buffer = Slice(UInt8).new(128)
    LibCrypto.hmac(evp, key_slice, key_slice.size, data_slice, data_slice.size, buffer, out buffer_len)
    buffer[0, buffer_len.to_i]
  end

  def self.hexdigest(algorithm : Symbol, key, data) : String
    digest(algorithm, key, data).hexstring
  end
end
