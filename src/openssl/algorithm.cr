require "openssl"

module OpenSSL
  # Indicates the possible hash algorithms for `OpenSSL` digest operations.
  enum Algorithm
    MD4
    MD5
    RIPEMD160
    SHA1
    SHA224
    SHA256
    SHA384
    SHA512

    # Returns the appropriate equivalent hash algorithm that corresponds to the
    # current enum value.
    #
    # The internal bindings to the `LibCrypto` digest operations sometimes require a hash algorithm
    # implementation to be passed as one of the arguments.
    def to_evp
      case self
      when MD4       then LibCrypto.evp_md4
      when MD5       then LibCrypto.evp_md5
      when RIPEMD160 then LibCrypto.evp_ripemd160
      when SHA1      then LibCrypto.evp_sha1
      when SHA224    then LibCrypto.evp_sha224
      when SHA256    then LibCrypto.evp_sha256
      when SHA384    then LibCrypto.evp_sha384
      when SHA512    then LibCrypto.evp_sha512
      else                raise "Unsupported algorithm: #{self}"
      end
    end
  end
end
