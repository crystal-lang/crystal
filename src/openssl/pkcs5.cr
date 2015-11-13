require "./lib_crypto"

class OpenSSL::PKCS5
  def self.pbkdf2_hmac_sha1(secret, salt, iterations = 2**16, key_size = 64)
    buffer = Slice(UInt8).new(key_size)
    LibCrypto.pkcs5_pbkdf2_hmac_sha1(secret, secret.size, salt, salt.size, iterations, key_size, buffer)
    buffer
  end
end
