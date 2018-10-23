require "openssl"

module OpenSSL::PKCS5
  def self.pbkdf2_hmac_sha1(secret, salt, iterations = 2**16, key_size = 64) : Bytes
    buffer = Bytes.new(key_size)
    if LibCrypto.pkcs5_pbkdf2_hmac_sha1(secret, secret.bytesize, salt, salt.bytesize, iterations, key_size, buffer) != 1
      raise OpenSSL::Error.new "pkcs5_pbkdf2_hmac"
    end
    buffer
  end

  {% if compare_versions(LibSSL::OPENSSL_VERSION, "1.0.0") >= 0 %}
  def self.pbkdf2_hmac(secret, salt, iterations = 2**16, algorithm : OpenSSL::Algorithm = OpenSSL::Algorithm::SHA1, key_size = 64) : Bytes
    evp = algorithm.to_evp
    buffer = Bytes.new(key_size)
    if LibCrypto.pkcs5_pbkdf2_hmac(secret, secret.bytesize, salt, salt.bytesize, iterations, evp, key_size, buffer) != 1
      raise OpenSSL::Error.new "pkcs5_pbkdf2_hmac"
    end
    buffer
  end
  {% end %}
end
