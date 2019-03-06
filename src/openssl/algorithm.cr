require "openssl"

module OpenSSL
  enum Algorithm
    # This enum indicates the possible hash algorithms for *OpenSSL* digest operations.
    MD4
    MD5
    RIPEMD160
    SHA1
    SHA224
    SHA256
    SHA384
    SHA512

    def to_evp
      # The internal bindings to the *LibCrypto* digest operations sometimes require a hash algorithm
      # implementation to be passed as one of the arguments.
      #
      # This method will return the appropriate equivalent hash algorithm that corresponds to the
      # current enum value.
      #
      case self
      when MD4       then LibCrypto.evp_md4
      when MD5       then LibCrypto.evp_md5
      when RIPEMD160 then LibCrypto.evp_ripemd160
      when SHA1      then LibCrypto.evp_sha1
      when SHA224    then LibCrypto.evp_sha224
      when SHA256    then LibCrypto.evp_sha256
      when SHA384    then LibCrypto.evp_sha384
      when SHA512    then LibCrypto.evp_sha512
      else                raise "Invalid algorithm: #{self}"
      end
    end
  end
end
