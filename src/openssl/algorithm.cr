require "openssl"

module OpenSSL
  enum Algorithm
    MD4
    MD5
    RIPEMD160
    SHA1
    SHA224
    SHA256
    SHA384
    SHA512

    def to_evp
      case self
      when OpenSSL::Algorithm::MD4       then LibCrypto.evp_md4
      when OpenSSL::Algorithm::MD5       then LibCrypto.evp_md5
      when OpenSSL::Algorithm::RIPEMD160 then LibCrypto.evp_ripemd160
      when OpenSSL::Algorithm::SHA1      then LibCrypto.evp_sha1
      when OpenSSL::Algorithm::SHA224    then LibCrypto.evp_sha224
      when OpenSSL::Algorithm::SHA256    then LibCrypto.evp_sha256
      when OpenSSL::Algorithm::SHA384    then LibCrypto.evp_sha384
      when OpenSSL::Algorithm::SHA512    then LibCrypto.evp_sha512
      else                                    raise "Invalid algorithm: #{self}"
      end
    end
  end
end
