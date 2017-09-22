require "openssl"

module OpenSSL::PKCS5
  def self.pbkdf2_hmac_sha1(secret, salt, iterations = 2**16, key_size = 64) : Bytes
    buffer = Bytes.new(key_size)
    if LibCrypto.pkcs5_pbkdf2_hmac_sha1(secret, secret.bytesize, salt, salt.bytesize, iterations, key_size, buffer) != 1
      raise OpenSSL::Error.new "pkcs5_pbkdf2_hmac_sha1"
    end
    buffer
  end

  def self.pbkdf2_hmac(algorithm : Symbol, secret, salt, iterations = 2**16, key_size = 64) : Bytes
    evp = case algorithm
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

    buffer = Bytes.new(key_size)
    if LibCrypto.pkcs5_pbkdf2_hmac(secret, secret.bytesize, salt, salt.bytesize, iterations, evp, key_size, buffer) != 1
      raise OpenSSL::Error.new "pkcs5_pbkdf2_hmac"
    end
    buffer
  end
end
